import 'dart:io';

import 'package:flutter/material.dart';

class FileHandler {
  @visibleForTesting
  static Directory? mockDirectory;

  static Directory createDirectory(String path) => mockDirectory ?? Directory(path);
}
