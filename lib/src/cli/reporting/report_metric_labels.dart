String labelForMetric(String key) {
  const labels = <String, String>{
    'classes': 'Classes renamed',
    'members': 'Members renamed',
    'variables': 'Variables renamed',
    'strings_encrypted': 'Strings encrypted',
  };

  if (labels.containsKey(key)) {
    return labels[key]!;
  }

  return key.split('_').map(_capitalize).join(' ');
}

String _capitalize(String value) {
  if (value.isEmpty) return value;
  return '${value[0].toUpperCase()}${value.substring(1)}';
}
