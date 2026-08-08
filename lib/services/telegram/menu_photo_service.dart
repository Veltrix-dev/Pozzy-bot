import 'dart:io' as io;

import 'package:pozzy_bot/config/config.dart';
import 'package:pozzy_bot/config/env_file_service.dart';
import 'package:pozzy_bot/services/telegram/menu_photo_key.dart';
import 'package:pozzy_bot/services/telegram/telegram_bot_http_api.dart';

class MenuPhotoService {
  MenuPhotoService({EnvFileService? envFile})
  : _envFile = envFile ?? EnvFileService();

  final EnvFileService _envFile;
  final Map<MenuPhotoKey, String> _fileIds = {};

  String? fileIdFor(MenuPhotoKey key) => _fileIds[key];

  void loadFromEnv(){
    for (final key in MenuPhotoKey.values) {
      final fromEnv = Config.menuPhotoFileId(key.envKey);
      if (fromEnv == null) continue;

      if(!_isCachedSourceValid(key)) continue;

      _fileIds[key] = fromEnv;
    }

    _dropDuplicateMainAndAdminFileIds();  
  }

  static bool isInvalidFileIdError(TelegramRichMessageResult result) {
    if(result.ok) return false;
    if(result.errorCode == 400) return true;

    final description = result.errorDescription?.toLowerCase() ?? '';
    return description.contains('wrong file identifier') ||
      description.contains('http=400');
  }

  void clearFileId(MenuPhotoKey key) {
    _fileIds.remove(key);
    Config.clearMenuPhotoFileId(key.envKey);
    Config.clearMenuPhotoSource(key.sourceEnvKey);
    _envFile.removeMenuPhotoKeys(key.envKey, key.sourceEnvKey);
  }

  void cacheFileId(
    MenuPhotoKey key,
    String fileId, {
    required String sourceFileName,
  }) {
    final trimmed = fileId.trim();
    if(trimmed.isEmpty) return;
    _fileIds[key] = trimmed;
    _envFile.updateMenuPhotoFileId(key.envKey, trimmed);
    _envFile.updateMenuPhotoSource(key.sourceEnvKey, sourceFileName);
    Config.applyMenuPhotoFileId(key.envKey, trimmed);
    Config.applyMenuPhotoSource(key.sourceEnvKey, sourceFileName);
    }

    static String? resolveMediaPathFor(MenuPhotoKey key) {
      for (final name in key.allFileNames) {
        final path = resolveMediaPath(name);
        if (path != null) return path;
      }
      return null;
    }
    
    static String sourceFileNameFromPath(String path) {
      final parts = path.split(RegExp(r'[/\\]'));
      return parts.isEmpty ? path: parts.last;
    }

    static String? resolveMediaPath(String fileName) {
      final relative = 'media${io.Platform.pathSeparator}photo';
      final fileOnly = io.File('$relative${io.Platform.pathSeparator}$fileName');
      if(fileOnly.existsSync()) return fileOnly.path;

      final nested = io.File(
       'pozzy_bot${io.Platform.pathSeparator}$relative${io.Platform.pathSeparator}$fileName', 
      );
      if(nested.existsSync()) return nested.path;

      var dir = io.Directory.current;
      while (true) {
        final pubspec = io.File('${dir.path}${io.Platform.pathSeparator}pubspec.yaml');
        if (pubspec.existsSync()) {
          final besidePubspec = io.File(
          '${dir.path}${io.Platform.pathSeparator}$relative${io.Platform.pathSeparator}$fileName',
          );
          return besidePubspec.existsSync() ? besidePubspec.path : null;
        }
        final parent = dir.parent;
        if (parent.path == dir.path) break;
        dir = parent;
      }
      return null;
    }

  bool _isCachedSourceValid(MenuPhotoKey key) {
    if(!_requiresSourceValidation(key)) return true;

    final cachedSource = Config.menuPhotoSource(key.sourceEnvKey);
    if(cachedSource == null || cachedSource.isEmpty) return false;

    return key.allFileNames.contains(cachedSource);
  }

  bool _requiresSourceValidation(MenuPhotoKey key) =>
  key == MenuPhotoKey.mainMenu || key == MenuPhotoKey.adminMenu;

  void _dropDuplicateMainAndAdminFileIds() {
    final mainId = _fileIds[MenuPhotoKey.mainMenu];
    final adminId = _fileIds[MenuPhotoKey.adminMenu];
    if(mainId == null || adminId == null) return;
  }
}