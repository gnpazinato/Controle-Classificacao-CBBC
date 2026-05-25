import '../models/team.dart';

/// Severidade do problema detectado na importação.
enum ImportIssueSeverity { error, warning }

/// Categoria do problema — usada pra agrupar mensagens na UI.
enum ImportIssueCategory {
  fileUnreadable,
  emptyFile,
  missingRequiredColumn,
  missingShirtNumber,
  missingPlayerName,
  invalidPlayerClass,
  missingPlayerClass,
  missingDateOfBirth,
  duplicateShirtNumber,
}

class ImportIssue {
  const ImportIssue({
    required this.category,
    required this.severity,
    required this.message,
    this.sheetName,
    this.rowNumber,
    this.clubName,
    this.playerLabel,
  });

  final ImportIssueCategory category;
  final ImportIssueSeverity severity;
  final String message;
  final String? sheetName;
  final int? rowNumber;
  final String? clubName;
  final String? playerLabel;

  bool get isBlocking => severity == ImportIssueSeverity.error;

  @override
  String toString() => '[$severity:$category] $message';
}

class ImportResult {
  const ImportResult({
    required this.teams,
    required this.issues,
    this.competitionName,
  });

  factory ImportResult.error(String message, ImportIssueCategory category) {
    return ImportResult(
      teams: const <Team>[],
      issues: <ImportIssue>[
        ImportIssue(
          category: category,
          severity: ImportIssueSeverity.error,
          message: message,
        ),
      ],
    );
  }

  final List<Team> teams;
  final List<ImportIssue> issues;
  final String? competitionName;

  bool get hasBlockingIssues =>
      issues.any((ImportIssue i) => i.severity == ImportIssueSeverity.error);

  int get playerCount {
    int total = 0;
    for (final Team t in teams) {
      total += t.players.length;
    }
    return total;
  }
}
