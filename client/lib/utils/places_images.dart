import 'package:flutter/material.dart';

/// Curated Unsplash image URLs mapped to countries and cities for trip cards.
/// These are direct URLs that don't require API calls.
class PlacesImages {
  PlacesImages._();

  static const Map<String, String> _placeImageUrls = {
    // ========== COUNTRIES ==========

    // Asia
    'japan':
        'https://images.unsplash.com/photo-1493976040374-85c8e12f0c0e?w=800',
    'thailand':
        'https://images.unsplash.com/photo-1504214208698-ea1916a2195a?w=800',
    'vietnam':
        'https://images.unsplash.com/photo-1557750255-c76072a7aad1?w=800',
    'indonesia':
        'https://images.unsplash.com/photo-1537996194471-e657df975ab4?w=800',
    'singapore':
        'https://images.unsplash.com/photo-1525625293386-3f8f99389edd?w=800',
    'south korea':
        'https://images.unsplash.com/photo-1538485399081-7191377e8241?w=800',
    'china':
        'https://images.unsplash.com/photo-1508804185872-d7badad00f7d?w=800',
    'india':
        'https://images.unsplash.com/photo-1524492412937-b28074a5d7da?w=800',
    'philippines':
        'https://images.unsplash.com/photo-1518509562904-e7ef99cdcc86?w=800',
    'malaysia':
        'https://images.unsplash.com/photo-1596422846543-75c6fc197f07?w=800',

    // Europe
    'france':
        'https://images.unsplash.com/photo-1499856871958-5b9627545d1a?w=800',
    'italy':
        'https://images.unsplash.com/photo-1523906834658-6e24ef2386f9?w=800',
    'spain': 'https://images.unsplash.com/photo-1543783207-ec64e4d95325?w=800',
    'germany':
        'https://images.unsplash.com/photo-1467269204594-9661b134dd2b?w=800',
    'united kingdom':
        'https://images.unsplash.com/photo-1513635269975-59663e0ac1ad?w=800',
    'uk': 'https://images.unsplash.com/photo-1513635269975-59663e0ac1ad?w=800',
    'greece':
        'https://images.unsplash.com/photo-1533105079780-92b9be482077?w=800',
    'netherlands':
        'https://images.unsplash.com/photo-1534351590666-13e3e96b5017?w=800',
    'portugal':
        'https://images.unsplash.com/photo-1555881400-74d7acaacd8b?w=800',
    'switzerland':
        'https://images.unsplash.com/photo-1530122037265-a5f1f91d3b99?w=800',
    'austria':
        'https://images.unsplash.com/photo-1516550893923-42d28e5677af?w=800',
    'czech republic':
        'https://images.unsplash.com/photo-1519677100203-a0e668c92439?w=800',
    'croatia':
        'https://images.unsplash.com/photo-1555990538-1e6c0c20f5c9?w=800',
    'iceland':
        'https://images.unsplash.com/photo-1504893524553-b855bce32c67?w=800',
    'norway':
        'https://images.unsplash.com/photo-1520769669658-f07657f5a307?w=800',
    'sweden':
        'https://images.unsplash.com/photo-1509356843151-3e7d96241e11?w=800',

    // Americas
    'united states':
        'https://images.unsplash.com/photo-1485738422979-f5c462d49f74?w=800',
    'usa': 'https://images.unsplash.com/photo-1485738422979-f5c462d49f74?w=800',
    'canada':
        'https://images.unsplash.com/photo-1517935706615-2717063c2225?w=800',
    'mexico':
        'https://images.unsplash.com/photo-1518105779142-d975f22f1b0a?w=800',
    'brazil':
        'https://images.unsplash.com/photo-1483729558449-99ef09a8c325?w=800',
    'argentina':
        'https://images.unsplash.com/photo-1589909202802-8f4aadce1849?w=800',
    'peru':
        'https://images.unsplash.com/photo-1526392060635-9d6019884377?w=800',
    'colombia':
        'https://images.unsplash.com/photo-1518638150340-f706e86654de?w=800',
    'costa rica':
        'https://images.unsplash.com/photo-1519999482648-25049ddd37b1?w=800',
    'cuba':
        'https://images.unsplash.com/photo-1500759285222-a95626b934cb?w=800',

    // Middle East & Africa
    'uae': 'https://images.unsplash.com/photo-1512453979798-5ea266f8880c?w=800',
    'united arab emirates':
        'https://images.unsplash.com/photo-1512453979798-5ea266f8880c?w=800',
    'egypt':
        'https://images.unsplash.com/photo-1539768942893-daf53e448371?w=800',
    'morocco':
        'https://images.unsplash.com/photo-1489749798305-4fea3ae63d43?w=800',
    'south africa':
        'https://images.unsplash.com/photo-1516026672322-bc52d61a55d5?w=800',
    'kenya': 'https://images.unsplash.com/photo-1547970810-dc1eac37d174?w=800',
    'israel': 'https://images.unsplash.com/photo-1544967082-d9d25d867d66?w=800',
    'turkey':
        'https://images.unsplash.com/photo-1524231757912-21f4fe3a7200?w=800',

    // Oceania
    'australia':
        'https://images.unsplash.com/photo-1506973035872-a4ec16b8e8d9?w=800',
    'new zealand':
        'https://images.unsplash.com/photo-1507699622108-4be3abd695ad?w=800',
    'fiji':
        'https://images.unsplash.com/photo-1589197331516-4d84b72ebde3?w=800',

    // ========== CITIES ==========

    // Major Cities - Americas
    'toronto':
        'https://images.unsplash.com/photo-1517090504586-fde19ea6066f?w=800',
    'new york':
        'https://images.unsplash.com/photo-1496442226666-8d4d0e62e6e9?w=800',
    'nyc': 'https://images.unsplash.com/photo-1496442226666-8d4d0e62e6e9?w=800',
    'los angeles':
        'https://images.unsplash.com/photo-1534190760961-74e8c1c5c3da?w=800',
    'la': 'https://images.unsplash.com/photo-1534190760961-74e8c1c5c3da?w=800',
    'vancouver':
        'https://images.unsplash.com/photo-1559511260-66a68e7d93e4?w=800',
    'miami':
        'https://images.unsplash.com/photo-1506966953602-c20cc11f75e3?w=800',
    'san francisco':
        'https://images.unsplash.com/photo-1501594907352-04cda38ebc29?w=800',
    'san diego':
        'https://images.unsplash.com/photo-1727203974139-fd59efe90bde?q=800',
    'chicago':
        'https://images.unsplash.com/photo-1494522855154-9297ac14b55f?w=800',
    'las vegas':
        'https://images.unsplash.com/photo-1605833556294-ea5c7a74f57d?w=800',
    'montreal':
        'https://images.unsplash.com/photo-1519178614-68673b201f36?w=800',
    'mexico city':
        'https://images.unsplash.com/photo-1518659526054-e25e0a5dc0c3?w=800',
    'rio de janeiro':
        'https://images.unsplash.com/photo-1483729558449-99ef09a8c325?w=800',
    'buenos aires':
        'https://images.unsplash.com/photo-1589909202802-8f4aadce1849?w=800',

    // Major Cities - Europe
    'london':
        'https://images.unsplash.com/photo-1513635269975-59663e0ac1ad?w=800',
    'paris':
        'https://images.unsplash.com/photo-1502602898657-3e91760cbb34?w=800',
    'rome': 'https://images.unsplash.com/photo-1552832230-c0197dd311b5?w=800',
    'barcelona':
        'https://images.unsplash.com/photo-1583422409516-2895a77efded?w=800',
    'amsterdam':
        'https://images.unsplash.com/photo-1534351590666-13e3e96b5017?w=800',
    'berlin': 'https://images.unsplash.com/photo-1560969184-10fe8719e047?w=800',
    'munich':
        'https://images.unsplash.com/photo-1595867818082-083862f3d630?w=800',
    'vienna':
        'https://images.unsplash.com/photo-1516550893923-42d28e5677af?w=800',
    'prague':
        'https://images.unsplash.com/photo-1519677100203-a0e668c92439?w=800',
    'lisbon': 'https://images.unsplash.com/photo-1555881400-74d7acaacd8b?w=800',
    'madrid':
        'https://images.unsplash.com/photo-1539037116277-4db20889f2d4?w=800',
    'athens': 'https://images.unsplash.com/photo-1555993539-1732b0258235?w=800',
    'istanbul':
        'https://images.unsplash.com/photo-1524231757912-21f4fe3a7200?w=800',
    'dublin': 'https://images.unsplash.com/photo-1549918864-48ac978761a4?w=800',
    'edinburgh':
        'https://images.unsplash.com/photo-1506377585622-bedcbb027afc?w=800',
    'zurich':
        'https://images.unsplash.com/photo-1515488764276-beab7607c1e6?w=800',
    'venice':
        'https://images.unsplash.com/photo-1523906834658-6e24ef2386f9?w=800',
    'florence':
        'https://images.unsplash.com/photo-1543429257-3eb0b65d9c58?w=800',
    'milan': 'https://images.unsplash.com/photo-1520440229-6469a149ac59?w=800',
    'copenhagen':
        'https://images.unsplash.com/photo-1513622470522-26c3c8a854bc?w=800',
    'stockholm':
        'https://images.unsplash.com/photo-1509356843151-3e7d96241e11?w=800',
    'oslo':
        'https://images.unsplash.com/photo-1533929736458-ca588d08c8be?w=800',
    'reykjavik':
        'https://images.unsplash.com/photo-1504893524553-b855bce32c67?w=800',

    // Major Cities - Asia
    'tokyo':
        'https://images.unsplash.com/photo-1540959733332-eab4deabeeaf?w=800',
    'osaka':
        'https://images.unsplash.com/photo-1590559899731-a382839e5549?w=800',
    'kyoto':
        'https://images.unsplash.com/photo-1493976040374-85c8e12f0c0e?w=800',
    'bangkok':
        'https://images.unsplash.com/photo-1528181304800-259b08848526?q=800',
    'phuket':
        'https://images.unsplash.com/photo-1589394815804-964ed0be2eb5?w=800',
    'hong kong':
        'https://images.unsplash.com/photo-1536599018102-9f803c140fc1?w=800',
    'shanghai':
        'https://images.unsplash.com/photo-1538428494232-9c0d8a3ab403?w=800',
    'beijing':
        'https://images.unsplash.com/photo-1508804185872-d7badad00f7d?w=800',
    'seoul':
        'https://images.unsplash.com/photo-1538485399081-7191377e8241?w=800',
    'taipei':
        'https://images.unsplash.com/photo-1470004914212-05527e49370b?w=800',
    'mumbai':
        'https://images.unsplash.com/photo-1529253355930-ddbe423a2ac7?w=800',
    'delhi':
        'https://images.unsplash.com/photo-1524492412937-b28074a5d7da?w=800',
    'hanoi': 'https://images.unsplash.com/photo-1557750255-c76072a7aad1?w=800',
    'ho chi minh':
        'https://images.unsplash.com/photo-1583417319070-4a69db38a482?w=800',
    'kuala lumpur':
        'https://images.unsplash.com/photo-1596422846543-75c6fc197f07?w=800',
    'bali':
        'https://images.unsplash.com/photo-1537996194471-e657df975ab4?w=800',
    'manila':
        'https://images.unsplash.com/photo-1518509562904-e7ef99cdcc86?w=800',

    // Major Cities - Middle East
    'dubai':
        'https://images.unsplash.com/photo-1512453979798-5ea266f8880c?w=800',
    'abu dhabi':
        'https://images.unsplash.com/photo-1512632578888-169bbbc64f33?w=800',
    'doha': 'https://images.unsplash.com/photo-1518684079-3c830dcef090?w=800',
    'tel aviv':
        'https://images.unsplash.com/photo-1544967082-d9d25d867d66?w=800',
    'jerusalem':
        'https://images.unsplash.com/photo-1552423314-cf29ab68ad73?w=800',
    'cairo':
        'https://images.unsplash.com/photo-1539768942893-daf53e448371?w=800',
    'marrakech':
        'https://images.unsplash.com/photo-1489749798305-4fea3ae63d43?w=800',

    // Major Cities - Oceania
    'sydney':
        'https://images.unsplash.com/photo-1506973035872-a4ec16b8e8d9?w=800',
    'melbourne':
        'https://images.unsplash.com/photo-1514395462725-fb4566210144?w=800',
    'auckland':
        'https://images.unsplash.com/photo-1507699622108-4be3abd695ad?w=800',
    'queenstown':
        'https://images.unsplash.com/photo-1589871973318-9ca1258faa5d?w=800',
  };

  static const String _defaultImageUrl =
      'https://images.unsplash.com/photo-1488646953014-85cb44e25828?w=800';

  /// Get image URL for a place. Accepts a list of location parts (e.g. ['San Diego', 'CA', 'USA'])
  /// and checks from left to right until a match is found. Returns default travel image if not found.
  static String getImageUrl(List<String>? placeParts) {
    if (placeParts == null || placeParts.isEmpty) return _defaultImageUrl;

    for (final part in placeParts) {
      final trimmed = part.trim();
      if (trimmed.isEmpty) continue;

      final url = _placeImageUrls[trimmed.toLowerCase()];
      if (url != null) return url;
    }

    return _defaultImageUrl;
  }

  /// Generate a gradient color pair based on place name for placeholders.
  static List<Color> getGradientColors(List<String>? placeParts) {
    if (placeParts == null || placeParts.isEmpty) {
      return [const Color(0xFF6366F1), const Color(0xFF8B5CF6)];
    }

    // Generate consistent colors based on first place part hash
    final place = placeParts.first;
    final hash = place.toLowerCase().hashCode;
    final hue = (hash % 360).abs().toDouble();

    return [
      HSLColor.fromAHSL(1.0, hue, 0.6, 0.5).toColor(),
      HSLColor.fromAHSL(1.0, (hue + 40) % 360, 0.7, 0.4).toColor(),
    ];
  }

  /// Get place initials for placeholder display.
  static String getPlaceInitials(List<String>? placeParts) {
    if (placeParts == null || placeParts.isEmpty) return '?';

    final place = placeParts.first.trim();
    if (place.isEmpty) return '?';

    final words = place.split(' ');
    if (words.length >= 2) {
      return '${words[0][0]}${words[1][0]}'.toUpperCase();
    }
    return place.substring(0, place.length >= 2 ? 2 : 1).toUpperCase();
  }
}
