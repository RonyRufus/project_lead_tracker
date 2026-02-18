class SpeechParser {
  static Map<String, String> parse(String transcript) {
    final result = {
      'buildingType': '',
      'architectName': '',
      'phoneNumber': '',
      'companyName': '',
      'notes': '',
    };

    if (transcript.isEmpty) return result;

    String remaining = transcript.trim();

    // Phone number
    final phoneRegex = RegExp(r'(\+?[\d][\d\s\-\(\)]{8,}[\d])');
    final phoneMatch = phoneRegex.firstMatch(remaining);
    if (phoneMatch != null) {
      result['phoneNumber'] =
          phoneMatch.group(0)!.trim().replaceAll(RegExp(r'\s+'), ' ');
      remaining = remaining.replaceFirst(phoneMatch.group(0)!, '').trim();
    }

    // Architect / contact name
    final architectRegex = RegExp(
      r'(?:architect|designed by|contact|designer|consultant)[:\s]+([A-Z][a-zA-Z\s\-]+?)(?:[,.]|$)',
      caseSensitive: false,
    );
    final archMatch = architectRegex.firstMatch(remaining);
    if (archMatch != null) {
      result['architectName'] = _titleCase(archMatch.group(1)!.trim());
      remaining = remaining.replaceFirst(archMatch.group(0)!, '').trim();
    }

    // Company name
    final companySuffixes = [
      'Pty Ltd', 'Pty', 'Ltd', 'Inc', 'LLC', 'Group', 'Builders',
      'Constructions', 'Developments', 'Projects', 'Architecture',
      'Design', 'Studio', 'Associates', 'Partners'
    ];
    for (final suffix in companySuffixes) {
      final escaped = RegExp.escape(suffix);
      final rx = RegExp(r'([A-Za-z][a-zA-Z\s&]+' + escaped + r')', caseSensitive: false);
      final m = rx.firstMatch(remaining);
      if (m != null) {
        result['companyName'] = _titleCase(m.group(0)!.trim());
        remaining = remaining.replaceFirst(m.group(0)!, '').trim();
        break;
      }
    }

    // Building type keywords
    final buildingKeywords = [
      'residential', 'commercial', 'industrial', 'retail', 'office',
      'warehouse', 'apartment', 'house', 'townhouse', 'duplex',
      'school', 'hospital', 'hotel', 'restaurant', 'cafe',
      'mixed use', 'civic', 'government', 'church', 'factory',
      'shed', 'garage', 'carpark', 'car park',
    ];
    for (final kw in buildingKeywords) {
      if (remaining.toLowerCase().contains(kw)) {
        result['buildingType'] = _titleCase(kw);
        final escaped = RegExp.escape(kw);
        final btRx = RegExp(
          r'([a-zA-Z\s]*?' + escaped + r'[a-zA-Z\s]*?)(?:[,.]|$)',
          caseSensitive: false,
        );
        final btMatch = btRx.firstMatch(remaining);
        if (btMatch != null) {
          result['buildingType'] = _titleCase(btMatch.group(1)!.trim());
          remaining = remaining.replaceFirst(btMatch.group(0)!, ' ').trim();
        }
        break;
      }
    }

    // Notes keyword
    final notesRegex = RegExp(
      r'(?:notes?|note|additional|comment)[:\s]+(.+)$',
      caseSensitive: false,
    );
    final notesMatch = notesRegex.firstMatch(remaining);
    if (notesMatch != null) {
      result['notes'] = notesMatch.group(1)!.trim();
      remaining = remaining.replaceFirst(notesMatch.group(0)!, '').trim();
    }

    // Fallback: first comma-segment becomes building type
    if (result['buildingType']!.isEmpty) {
      final segments = remaining.split(RegExp(r'[,.]'));
      if (segments.isNotEmpty && segments.first.trim().isNotEmpty) {
        final words = segments.first.trim().split(' ');
        result['buildingType'] = _titleCase(words.take(5).join(' '));
        remaining = remaining
            .replaceFirst(segments.first, '')
            .replaceFirst(RegExp(r'^[,.]?\s*'), '');
      }
    }

    // Remainder goes to notes
    remaining = remaining
        .replaceAll(RegExp(r'^[,.\s]+'), '')
        .replaceAll(RegExp(r'[,.\s]+$'), '')
        .trim();
    if (remaining.isNotEmpty) {
      result['notes'] = result['notes']!.isEmpty
          ? remaining
          : '${result['notes']!} $remaining'.trim();
    }

    return result;
  }

  static String _titleCase(String s) {
    return s
        .split(' ')
        .map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1).toLowerCase())
        .join(' ');
  }
}
