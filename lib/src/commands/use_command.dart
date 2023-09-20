import 'package:args/command_runner.dart';
import 'package:fvm/fvm.dart';
import 'package:fvm/src/services/releases_service/releases_client.dart';
import 'package:fvm/src/utils/helpers.dart';
import 'package:fvm/src/workflows/ensure_cache.workflow.dart';
import 'package:fvm/src/workflows/setup_flutter_workflow.dart';
import 'package:io/io.dart';

import '../services/logger_service.dart';
import '../utils/console_utils.dart';
import '../workflows/use_version.workflow.dart';
import 'base_command.dart';

/// Use an installed SDK version
class UseCommand extends BaseCommand {
  @override
  final name = 'use';

  @override
  String description =
      'Sets Flutter SDK Version you would like to use in a project';

  @override
  String get invocation => 'fvm use {version}';

  /// Constructor
  UseCommand() {
    argParser
      ..addFlag(
        'force',
        help: 'Skips command guards that does Flutter project checks.',
        abbr: 'f',
        negatable: false,
      )
      ..addFlag(
        'pin',
        help:
            '''If version provided is a channel. Will pin the latest release of the channel''',
        abbr: 'p',
        negatable: false,
      )
      ..addOption(
        'flavor',
        help: 'Sets version for a project flavor',
        defaultsTo: null,
      )
      ..addFlag(
        'skip-setup',
        help: 'Skips Flutter setup after install',
        negatable: false,
      );
  }
  @override
  Future<int> run() async {
    final forceOption = boolArg('force');
    final pinOption = boolArg('pin');
    final flavorOption = stringArg('flavor');
    final skipSetup = boolArg('skip-setup');

    String? version;

    final project = ProjectService.fromContext.findAncestor();

    // If no version was passed as argument check project config.
    if (argResults!.rest.isEmpty) {
      version = project.pinnedVersion;
      final versions = await CacheService.fromContext.getAllVersions();
      // If no config found, ask which version to select.
      version ??= await cacheVersionSelector(versions);
    }

    // Get version from first arg
    version ??= argResults!.rest[0];

    // Get valid flutter version. Force version if is to be pinned.

    if (pinOption && isFlutterChannel(version)) {
      /// Cannot pin master channel
      if (version == 'master') {
        throw UsageException(
          'Cannot pin a version from "master" channel.',
          usage,
        );
      }

      /// Pin release to channel

      final release = await FlutterReleasesClient.getLatestReleaseOfChannel(
        FlutterChannel.fromName(version),
      );

      logger.info(
        'Pinning version ${release.version} from "$version" release channel...',
      );

      version = release.version;
    }

    final cacheVersion = await ensureCacheWorkflow(version);

    if (!skipSetup && cacheVersion.notSetup) {
      await setupFlutterWorkflow(
        version: cacheVersion,
      );
    }

    /// Run use workflow
    await useVersionWorkflow(
      version: cacheVersion,
      project: project,
      force: forceOption,
      flavor: flavorOption,
    );

    return ExitCode.success.code;
  }
}
