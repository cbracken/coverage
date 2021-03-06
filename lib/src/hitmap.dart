library coverage.hitmap;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Creates a single hitmap from a raw json object. Throws away all entries that
/// are not resolvable.
Map createHitmap(List<Map> json) {
  // Map of source file to map of line to hit count for that line.
  var globalHitMap = <String, Map<int, int>>{};

  void addToMap(Map<int, int> map, int line, int count) {
    var oldCount = map.putIfAbsent(line, () => 0);
    map[line] = count + oldCount;
  }

  for (Map e in json) {
    var source = e['source'];
    if (source == null) {
      // Couldn't resolve import, so skip this entry.
      continue;
    }

    var sourceHitMap = globalHitMap.putIfAbsent(source, () => <int, int>{});
    var hits = e['hits'];
    // hits is a flat array of the following format:
    // [ <line|linerange>, <hitcount>,...]
    // line: number.
    // linerange: '<line>-<line>'.
    for (var i = 0; i < hits.length; i += 2) {
      var k = hits[i];
      if (k is num) {
        // Single line.
        addToMap(sourceHitMap, k, hits[i + 1]);
      } else {
        assert(k is String);
        // Linerange. We expand line ranges to actual lines at this point.
        var splitPos = k.indexOf('-');
        int start = int.parse(k.substring(0, splitPos));
        int end = int.parse(k.substring(splitPos + 1));
        for (var j = start; j <= end; j++) {
          addToMap(sourceHitMap, j, hits[i + 1]);
        }
      }
    }
  }
  return globalHitMap;
}

/// Merges [newMap] into [result].
void mergeHitmaps(Map newMap, Map result) {
  newMap.forEach((String file, Map v) {
    if (result.containsKey(file)) {
      v.forEach((int line, int cnt) {
        if (result[file][line] == null) {
          result[file][line] = cnt;
        } else {
          result[file][line] += cnt;
        }
      });
    } else {
      result[file] = v;
    }
  });
}

/// Generates a merged hitmap from a set of coverage JSON files.
Future<Map> parseCoverage(Iterable<File> files, _) async {
  Map globalHitmap = {};
  for (var file in files) {
    String contents = file.readAsStringSync();
    var json = JSON.decode(contents)['coverage'] as List<Map>;
    mergeHitmaps(createHitmap(json), globalHitmap);
  }
  return globalHitmap;
}
