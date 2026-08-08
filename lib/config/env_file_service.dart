import 'dart:io';

import 'package:pozzy_bot/config/config.dart';

class EnvFileService {

  void updateMenuPhotoFileId(String envKey, String fileId) {
    final path = Config.envFilePath;
    if(path == null) return;


    upsertKey(
      path: path,
      key: envKey,
      value: fileId,
      removeKeys: const {},
    );
  }

  void updateMenuPhotoSource(String envKey, String sourceFileName) {
    final path = Config.envFilePath;
    if(path == null) return;
    
    upsertKey(
      path: path,
      key: envKey,
      value: sourceFileName,
      removeKeys: const {},
    );
  }

  void removeMenuPhotoKeys(String fileIdEnvKey, String sourceEnvKey) {
    final path = Config.envFilePath;
    if(path == null) return;
    
    removeKeys(path: path, keys: {fileIdEnvKey, sourceEnvKey});
  }

  String _requireEnvPath() {
   final path = Config.envFilePath;
   if(path == null) {
    throw StateError('.env file not found');
   }
   return path;
  }

  void removeKeys({required String path, required Set<String> keys}) {
    final file = File(path);
    if (!file.existsSync()) return;

    final updated = file
    .readAsLinesSync()
    .where((line) {
      final parsedKey = parseKey(line);
      return parsedKey == null || !keys.contains(parsedKey);
    }).toList();

    file.writeAsStringSync('${updated.join('\n')}\n');
  }

  void upsertKey({
    required String path,
    required String key,
    required String value,
    required Set<String> removeKeys,
  }) {
    final file = File(path);
    final lines = file.existsSync() ? file.readAsLinesSync() : <String>[];
    final keysToReplace = {key, ...removeKeys};

    var replaced = false;
    final updated = <String>[];

    for (final line in lines) {
      final parsedKey = parseKey(line);
      if(parsedKey != null && keysToReplace.contains(parsedKey)){
        if(!replaced) {
          updated.add('$key=$value');
          replaced = true;
        }
        continue;
      }
      updated.add(line);
    }

  if(!replaced) {
    updated.add('$key=$value');
  }

  file.writeAsStringSync('${updated.join('\n')}\n');
 }

 String? parseKey(String line){
  final trimmed = line.trim();
  if(trimmed.isEmpty || trimmed.startsWith('#')) return null;
  final index = trimmed.indexOf('=');
  if(index <= 0) return null;
  return trimmed.substring(0, index).trim();
 }

}