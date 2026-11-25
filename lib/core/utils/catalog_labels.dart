/// Short Castilian names for addons and their catalogs.
///
/// Addons name things for Stremio's own UI: "TvVoo | ElfHosted",
/// "TvVoo • Spain", "StremVerse IPTV"… Once a catalog sits under its
/// addon's tab, the addon name is noise, and the rest is often English.
library;

/// "TvVoo | ElfHosted" → "TvVoo": the part before a host/brand suffix.
String addonLabel(String name) {
  final short = name.split(RegExp(r'\s+[|–—-]\s+')).first.trim();
  return short.isEmpty ? name.trim() : short;
}

/// "TvVoo • Spain" under "TvVoo" → "España"; "StremVerse IPTV" → "IPTV".
String catalogLabel(String catalogName, String addonName) {
  var label = catalogName.trim();
  final addon = addonLabel(addonName);
  // Drop the addon's name where it repeats, plus the separator next to it.
  if (addon.isNotEmpty) {
    label = label.replaceAll(
      RegExp(
        r'(^|\s)' + RegExp.escape(addon) + r'(\s*[•·|:–—-]\s*|\s+|$)',
        caseSensitive: false,
      ),
      ' ',
    );
  }
  label = label
      .replaceAll(RegExp(r'^[\s•·|:–—-]+|[\s•·|:–—-]+$'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (label.isEmpty) return addon.isEmpty ? catalogName.trim() : addon;
  return _translations[label.toLowerCase()] ?? label;
}

const _translations = {
  // Countries (TvVoo)
  'spain': 'España',
  'italy': 'Italia',
  'united kingdom': 'Reino Unido',
  'uk': 'Reino Unido',
  'france': 'Francia',
  'germany': 'Alemania',
  'portugal': 'Portugal',
  'albania': 'Albania',
  'turkey': 'Turquía',
  'netherlands': 'Países Bajos',
  'arabic': 'Árabe',
  'balkans': 'Balcanes',
  'russia': 'Rusia',
  'romania': 'Rumanía',
  'poland': 'Polonia',
  'bulgaria': 'Bulgaria',
  'usa': 'Estados Unidos',
  'united states': 'Estados Unidos',
  'mexico': 'México',
  'argentina': 'Argentina',
  // Common catalog names
  'live events': 'Eventos en directo',
  'live': 'En directo',
  'live tv': 'TV en directo',
  'replays': 'Repeticiones',
  'highlights': 'Resúmenes',
  'channels': 'Canales',
  'tv channels': 'Canales',
  'sports': 'Deportes',
  'sport': 'Deportes',
  'movies': 'Cine',
  'news': 'Noticias',
  'kids': 'Infantil',
  'music': 'Música',
  'documentaries': 'Documentales',
};
