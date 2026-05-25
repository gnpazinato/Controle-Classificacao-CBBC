/// Classes funcionais aceitas para basquetebol em cadeira de rodas
/// (mesmo padrão IWBF adotado pela CBBC).
const List<double> kAcceptedPlayerClasses = <double>[
  1.0,
  1.5,
  2.0,
  2.5,
  3.0,
  3.5,
  4.0,
  4.5,
];

const double kMinPlayerClass = 1.0;
const double kMaxPlayerClass = 4.5;

bool isAcceptedPlayerClass(double value) {
  for (final double accepted in kAcceptedPlayerClasses) {
    if ((accepted - value).abs() < 0.0001) {
      return true;
    }
  }
  return false;
}

/// Converte representação textual (`"2.5"` ou `"2,5"`) para [double].
double? parsePlayerClass(String? raw) {
  if (raw == null) return null;
  final String trimmed = raw.trim();
  if (trimmed.isEmpty) return null;
  final String normalized = trimmed.replaceAll(',', '.');
  final double? parsed = double.tryParse(normalized);
  if (parsed == null) return null;
  if (!isAcceptedPlayerClass(parsed)) return null;
  return parsed;
}
