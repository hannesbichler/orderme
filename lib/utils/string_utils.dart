import 'dart:convert';

import 'package:crypto/crypto.dart';

const _htmlEntities = <String, String>{
  // Special
  '&amp;':   '&',
  '&lt;':    '<',
  '&gt;':    '>',
  '&quot;':  '"',
  '&#39;':   "'",
  '&apos;':  "'",
  '&nbsp;':  '\u00A0',
  // Symbols
  '&copy;':  '©',
  '&reg;':   '®',
  '&trade;': '™',
  '&euro;':  '€',
  '&pound;': '£',
  '&yen;':   '¥',
  '&cent;':  '¢',
  '&mdash;': '—',
  '&ndash;': '–',
  '&hellip;':'…',
  '&laquo;': '«',
  '&raquo;': '»',
  // Accented Latin — lowercase
  '&agrave;': 'à', '&aacute;': 'á', '&acirc;': 'â', '&atilde;': 'ã',
  '&auml;':   'ä', '&aring;':  'å', '&aelig;':  'æ', '&ccedil;': 'ç',
  '&egrave;': 'è', '&eacute;': 'é', '&ecirc;':  'ê', '&euml;':   'ë',
  '&igrave;': 'ì', '&iacute;': 'í', '&icirc;':  'î', '&iuml;':   'ï',
  '&ntilde;': 'ñ',
  '&ograve;': 'ò', '&oacute;': 'ó', '&ocirc;':  'ô', '&otilde;': 'õ',
  '&ouml;':   'ö', '&oslash;': 'ø',
  '&ugrave;': 'ù', '&uacute;': 'ú', '&ucirc;':  'û', '&uuml;':   'ü',
  '&yacute;': 'ý', '&yuml;':   'ÿ',
  '&szlig;':  'ß',
  // Accented Latin — uppercase
  '&Agrave;': 'À', '&Aacute;': 'Á', '&Acirc;': 'Â', '&Atilde;': 'Ã',
  '&Auml;':   'Ä', '&Aring;':  'Å', '&AElig;':  'Æ', '&Ccedil;': 'Ç',
  '&Egrave;': 'È', '&Eacute;': 'É', '&Ecirc;':  'Ê', '&Euml;':   'Ë',
  '&Igrave;': 'Ì', '&Iacute;': 'Í', '&Icirc;':  'Î', '&Iuml;':   'Ï',
  '&Ntilde;': 'Ñ',
  '&Ograve;': 'Ò', '&Oacute;': 'Ó', '&Ocirc;':  'Ô', '&Otilde;': 'Õ',
  '&Ouml;':   'Ö', '&Oslash;': 'Ø',
  '&Ugrave;': 'Ù', '&Uacute;': 'Ú', '&Ucirc;':  'Û', '&Uuml;':   'Ü',
  '&Yacute;': 'Ý',
};

/// Decodes common escape sequences and HTML entities in a string.
String unescape(String input) {
  // 1. Named HTML entities
  var result = input;
  for (final entry in _htmlEntities.entries) {
    result = result.replaceAll(entry.key, entry.value);
  }

  // 2. Numeric HTML entities  &#65;  or  &#x41;
  result = result.replaceAllMapped(
    RegExp(r'&#(?:x([0-9a-fA-F]+)|([0-9]+));'),
    (m) {
      final code = m[1] != null
          ? int.parse(m[1]!, radix: 16)
          : int.parse(m[2]!);
      return String.fromCharCode(code);
    },
  );

  // 3. Unicode escape sequences  \uXXXX
  result = result.replaceAllMapped(
    RegExp(r'\\u([0-9a-fA-F]{4})'),
    (m) => String.fromCharCode(int.parse(m[1]!, radix: 16)),
  );

  // 4. Common backslash escapes
  return result
      .replaceAll(r'\\', '\\')
      .replaceAll(r'\"', '"')
      .replaceAll(r"\'", "'")
      .replaceAll(r'\n', '\n')
      .replaceAll(r'\r', '\r')
      .replaceAll(r'\t', '\t');
}

/// Decodes a percent-encoded (URL-encoded) string.
String urlDecode(String input) => Uri.decodeComponent(input);

/// Returns the SHA-1 hash of the provided string as a lowercase hex digest.
String sha1FromString(String input) {
  return "sha1:${sha1.convert(utf8.encode(input)).toString().toUpperCase()}";
}
