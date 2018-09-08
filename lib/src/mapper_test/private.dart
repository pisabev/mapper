import 'dart:io';

void run(ProcessResult processResult) {
  if (processResult.exitCode != 0) throw new Exception(processResult.stderr);
}