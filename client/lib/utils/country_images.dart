import 'package:flutter/material.dart';

/// Curated Unsplash image URLs mapped to countries for trip cards.
/// These are direct URLs that don't require API calls.
class CountryImages {
  CountryImages._();

  static const Map<String, String> _countryImageUrls = {
    // Asia
    'japan': 'https://images.unsplash.com/photo-1493976040374-85c8e12f0c0e?w=800',
    'thailand': 'https://images.unsplash.com/photo-1504214208698-ea1916a2195a?w=800',
    'vietnam': 'https://images.unsplash.com/photo-1557750255-c76072a7aad1?w=800',
    'indonesia': 'https://images.unsplash.com/photo-1537996194471-e657df975ab4?w=800',
    'singapore': 'https://images.unsplash.com/photo-1525625293386-3f8f99389edd?w=800',
    'south korea': 'https://images.unsplash.com/photo-1538485399081-7191377e8241?w=800',
    'china': 'https://images.unsplash.com/photo-1508804185872-d7badad00f7d?w=800',
    'india': 'https://images.unsplash.com/photo-1524492412937-b28074a5d7da?w=800',
    'philippines': 'https://images.unsplash.com/photo-1518509562904-e7ef99cdcc86?w=800',
    'malaysia': 'https://images.unsplash.com/photo-1596422846543-75c6fc197f07?w=800',

    // Europe
    'france': 'https://images.unsplash.com/photo-1499856871958-5b9627545d1a?w=800',
    'italy': 'https://images.unsplash.com/photo-1523906834658-6e24ef2386f9?w=800',
    'spain': 'https://images.unsplash.com/photo-1543783207-ec64e4d95325?w=800',
    'germany': 'https://images.unsplash.com/photo-1467269204594-9661b134dd2b?w=800',
    'united kingdom': 'https://images.unsplash.com/photo-1513635269975-59663e0ac1ad?w=800',
    'uk': 'https://images.unsplash.com/photo-1513635269975-59663e0ac1ad?w=800',
    'greece': 'https://images.unsplash.com/photo-1533105079780-92b9be482077?w=800',
    'netherlands': 'https://images.unsplash.com/photo-1534351590666-13e3e96b5017?w=800',
    'portugal': 'https://images.unsplash.com/photo-1555881400-74d7acaacd8b?w=800',
    'switzerland': 'https://images.unsplash.com/photo-1530122037265-a5f1f91d3b99?w=800',
    'austria': 'https://images.unsplash.com/photo-1516550893923-42d28e5677af?w=800',
    'czech republic': 'https://images.unsplash.com/photo-1519677100203-a0e668c92439?w=800',
    'croatia': 'https://images.unsplash.com/photo-1555990538-1e6c0c20f5c9?w=800',
    'iceland': 'https://images.unsplash.com/photo-1504893524553-b855bce32c67?w=800',
    'norway': 'https://images.unsplash.com/photo-1520769669658-f07657f5a307?w=800',
    'sweden': 'https://images.unsplash.com/photo-1509356843151-3e7d96241e11?w=800',

    // Americas
    'united states': 'https://images.unsplash.com/photo-1485738422979-f5c462d49f74?w=800',
    'usa': 'https://images.unsplash.com/photo-1485738422979-f5c462d49f74?w=800',
    'canada': 'https://images.unsplash.com/photo-1517935706615-2717063c2225?w=800',
    'mexico': 'https://images.unsplash.com/photo-1518105779142-d975f22f1b0a?w=800',
    'brazil': 'https://images.unsplash.com/photo-1483729558449-99ef09a8c325?w=800',
    'argentina': 'https://images.unsplash.com/photo-1589909202802-8f4aadce1849?w=800',
    'peru': 'https://images.unsplash.com/photo-1526392060635-9d6019884377?w=800',
    'colombia': 'https://images.unsplash.com/photo-1518638150340-f706e86654de?w=800',
    'costa rica': 'https://images.unsplash.com/photo-1519999482648-25049ddd37b1?w=800',
    'cuba': 'https://images.unsplash.com/photo-1500759285222-a95626b934cb?w=800',

    // Middle East & Africa
    'uae': 'https://images.unsplash.com/photo-1512453979798-5ea266f8880c?w=800',
    'united arab emirates': 'https://images.unsplash.com/photo-1512453979798-5ea266f8880c?w=800',
    'egypt': 'https://images.unsplash.com/photo-1539768942893-daf53e448371?w=800',
    'morocco': 'https://images.unsplash.com/photo-1489749798305-4fea3ae63d43?w=800',
    'south africa': 'https://images.unsplash.com/photo-1516026672322-bc52d61a55d5?w=800',
    'kenya': 'https://images.unsplash.com/photo-1547970810-dc1eac37d174?w=800',
    'israel': 'https://images.unsplash.com/photo-1544967082-d9d25d867d66?w=800',
    'turkey': 'https://images.unsplash.com/photo-1524231757912-21f4fe3a7200?w=800',

    // Oceania
    'australia': 'https://images.unsplash.com/photo-1506973035872-a4ec16b8e8d9?w=800',
    'new zealand': 'https://images.unsplash.com/photo-1507699622108-4be3abd695ad?w=800',
    'fiji': 'https://images.unsplash.com/photo-1589197331516-4d84b72ebde3?w=800',
  };

  static const String _defaultImageUrl =
      'https://images.unsplash.com/photo-1488646953014-85cb44e25828?w=800';

  /// Get image URL for a country. Returns default travel image if not found.
  static String getImageUrl(String? country) {
    if (country == null || country.isEmpty) return _defaultImageUrl;
    return _countryImageUrls[country.toLowerCase()] ?? _defaultImageUrl;
  }

  /// Generate a gradient color pair based on country name for placeholders.
  static List<Color> getGradientColors(String? country) {
    if (country == null || country.isEmpty) {
      return [const Color(0xFF6366F1), const Color(0xFF8B5CF6)];
    }

    // Generate consistent colors based on country name hash
    final hash = country.toLowerCase().hashCode;
    final hue = (hash % 360).abs().toDouble();

    return [
      HSLColor.fromAHSL(1.0, hue, 0.6, 0.5).toColor(),
      HSLColor.fromAHSL(1.0, (hue + 40) % 360, 0.7, 0.4).toColor(),
    ];
  }

  /// Get country initials for placeholder display.
  static String getCountryInitials(String? country) {
    if (country == null || country.isEmpty) return '?';

    final words = country.trim().split(' ');
    if (words.length >= 2) {
      return '${words[0][0]}${words[1][0]}'.toUpperCase();
    }
    return country.substring(0, country.length >= 2 ? 2 : 1).toUpperCase();
  }
}

