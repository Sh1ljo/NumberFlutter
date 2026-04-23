bool isLikelyNetworkError(Object? error) {
  final message = error?.toString().toLowerCase() ?? '';
  return message.contains('socketexception') ||
      message.contains('failed host lookup') ||
      message.contains('network') ||
      message.contains('connection') ||
      message.contains('timed out') ||
      message.contains('timeout') ||
      message.contains('clientexception') ||
      message.contains('handshake');
}

String cloudErrorMessage(
  Object? error, {
  required String offlineMessage,
  required String fallbackMessage,
}) {
  if (isLikelyNetworkError(error)) {
    return offlineMessage;
  }
  return fallbackMessage;
}
