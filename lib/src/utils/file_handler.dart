import 'dart:io';

import 'package:flutter/material.dart';

class FileHandler {
  @visibleForTesting
  static Directory? mockDirectory;

  @visibleForTesting
  static File? mockFile;

  static Directory createDirectory(String path) => mockDirectory ?? Directory(path);
  static File createFile(String path) => mockFile ?? File(path);
}
