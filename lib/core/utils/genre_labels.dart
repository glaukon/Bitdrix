/// Castilian names for the genre/category filters addons send, which come
/// in English (TvVoo: "Sport", "Movies"…) or Italian (its Italy lists).
///
/// Only for display: the original value is what goes back to the addon.
String genreLabel(String genre) {
  final key = genre.trim().toLowerCase();
  final known = _labels[key];
  if (known != null) return known;
  if (key.isEmpty) return genre;
  // Unknown: keep it, just with a capital first letter.
  final trimmed = genre.trim();
  return trimmed[0].toUpperCase() + trimmed.substring(1);
}

const _labels = {
  // English
  'sport': 'Deportes',
  'sports': 'Deportes',
  'movies': 'Cine',
  'movie': 'Cine',
  'cinema': 'Cine',
  'films': 'Cine',
  'news': 'Noticias',
  'documentary': 'Documentales',
  'documentaries': 'Documentales',
  'kids': 'Infantil',
  'children': 'Infantil',
  'music': 'Música',
  'general': 'Generalistas',
  'entertainment': 'Entretenimiento',
  'vod': 'A la carta',
  'lifestyle': 'Estilo de vida',
  'series': 'Series',
  'religious': 'Religión',
  'religion': 'Religión',
  'shopping': 'Teletienda',
  'local': 'Locales',
  'regional': 'Autonómicas',
  'culture': 'Cultura',
  'education': 'Educación',
  'cooking': 'Cocina',
  'travel': 'Viajes',
  'comedy': 'Comedia',
  'animation': 'Animación',
  'adult': 'Adultos',
  'other': 'Otros',
  'others': 'Otros',
  // Italian
  'calcio': 'Fútbol',
  'intrattenimento': 'Entretenimiento',
  'notizie': 'Noticias',
  'informazione': 'Noticias',
  'documentari': 'Documentales',
  'bambini': 'Infantil',
  'ragazzi': 'Infantil',
  'musica': 'Música',
  'generali': 'Generalistas',
  'generalisti': 'Generalistas',
  'serie': 'Series',
  'serie tv': 'Series',
  'regionali': 'Autonómicas',
  'locali': 'Locales',
  'religiosi': 'Religión',
  'cucina': 'Cocina',
  'viaggi': 'Viajes',
  'altri': 'Otros',
};
