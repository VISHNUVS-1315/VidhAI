import 'package:vidhai/services/market_price_service.dart';

/// India-only state/district catalog used by onboarding and farm setup.
///
/// State names are available offline. Districts are fetched from VidhAI's
/// cached/live AGMARKNET-backed service and merged with offline fallbacks for
/// the southern states most commonly used by the app demo.
class IndiaLocationCatalog {
  IndiaLocationCatalog._();

  static const states = <String>[
    'Andaman and Nicobar Islands',
    'Andhra Pradesh',
    'Arunachal Pradesh',
    'Assam',
    'Bihar',
    'Chandigarh',
    'Chhattisgarh',
    'Dadra and Nagar Haveli and Daman and Diu',
    'Delhi',
    'Goa',
    'Gujarat',
    'Haryana',
    'Himachal Pradesh',
    'Jammu and Kashmir',
    'Jharkhand',
    'Karnataka',
    'Kerala',
    'Ladakh',
    'Lakshadweep',
    'Madhya Pradesh',
    'Maharashtra',
    'Manipur',
    'Meghalaya',
    'Mizoram',
    'Nagaland',
    'Odisha',
    'Puducherry',
    'Punjab',
    'Rajasthan',
    'Sikkim',
    'Tamil Nadu',
    'Telangana',
    'Tripura',
    'Uttar Pradesh',
    'Uttarakhand',
    'West Bengal',
  ];

  static const _fallbackDistricts = <String, List<String>>{
    'Tamil Nadu': [
      'Ariyalur',
      'Chengalpattu',
      'Chennai',
      'Coimbatore',
      'Cuddalore',
      'Dharmapuri',
      'Dindigul',
      'Erode',
      'Kallakurichi',
      'Kancheepuram',
      'Kanniyakumari',
      'Karur',
      'Krishnagiri',
      'Madurai',
      'Mayiladuthurai',
      'Nagapattinam',
      'Namakkal',
      'Nilgiris',
      'Perambalur',
      'Pudukkottai',
      'Ramanathapuram',
      'Ranipet',
      'Salem',
      'Sivaganga',
      'Tenkasi',
      'Thanjavur',
      'Theni',
      'Thoothukudi',
      'Tiruchirappalli',
      'Tirunelveli',
      'Tirupathur',
      'Tiruppur',
      'Tiruvallur',
      'Tiruvannamalai',
      'Tiruvarur',
      'Vellore',
      'Viluppuram',
      'Virudhunagar',
    ],
    'Kerala': [
      'Alappuzha',
      'Ernakulam',
      'Idukki',
      'Kannur',
      'Kasaragod',
      'Kollam',
      'Kottayam',
      'Kozhikode',
      'Malappuram',
      'Palakkad',
      'Pathanamthitta',
      'Thiruvananthapuram',
      'Thrissur',
      'Wayanad',
    ],
    'Karnataka': [
      'Bagalkote',
      'Ballari',
      'Belagavi',
      'Bengaluru Rural',
      'Bengaluru Urban',
      'Bidar',
      'Chamarajanagar',
      'Chikkaballapur',
      'Chikkamagaluru',
      'Chitradurga',
      'Dakshina Kannada',
      'Davanagere',
      'Dharwad',
      'Gadag',
      'Hassan',
      'Haveri',
      'Kalaburagi',
      'Kodagu',
      'Kolar',
      'Koppal',
      'Mandya',
      'Mysuru',
      'Raichur',
      'Ramanagara',
      'Shivamogga',
      'Tumakuru',
      'Udupi',
      'Uttara Kannada',
      'Vijayapura',
      'Vijayanagara',
      'Yadgir',
    ],
    'Andhra Pradesh': [
      'Alluri Sitharama Raju',
      'Anakapalli',
      'Ananthapuramu',
      'Annamayya',
      'Bapatla',
      'Chittoor',
      'Dr. B. R. Ambedkar Konaseema',
      'East Godavari',
      'Eluru',
      'Guntur',
      'Kakinada',
      'Krishna',
      'Kurnool',
      'Nandyal',
      'NTR',
      'Palnadu',
      'Parvathipuram Manyam',
      'Prakasam',
      'Sri Potti Sriramulu Nellore',
      'Sri Sathya Sai',
      'Srikakulam',
      'Tirupati',
      'Visakhapatnam',
      'Vizianagaram',
      'West Godavari',
      'YSR Kadapa',
    ],
    'Telangana': [
      'Adilabad',
      'Bhadradri Kothagudem',
      'Hanumakonda',
      'Hyderabad',
      'Jagtial',
      'Jangaon',
      'Jayashankar Bhupalpally',
      'Jogulamba Gadwal',
      'Kamareddy',
      'Karimnagar',
      'Khammam',
      'Kumuram Bheem Asifabad',
      'Mahabubabad',
      'Mahabubnagar',
      'Mancherial',
      'Medak',
      'Medchal-Malkajgiri',
      'Mulugu',
      'Nagarkurnool',
      'Nalgonda',
      'Narayanpet',
      'Nirmal',
      'Nizamabad',
      'Peddapalli',
      'Rajanna Sircilla',
      'Rangareddy',
      'Sangareddy',
      'Siddipet',
      'Suryapet',
      'Vikarabad',
      'Wanaparthy',
      'Warangal',
      'Yadadri Bhuvanagiri',
    ],
    'Puducherry': [
      'Karaikal',
      'Mahe',
      'Puducherry',
      'Yanam',
    ],
  };

  static final Map<String, List<String>> _memoryCache = {};

  static List<String> searchStates(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return states;
    return states
        .where((state) => state.toLowerCase().contains(q))
        .toList(growable: false);
  }

  static Future<List<String>> districtsForState(String state) async {
    final clean = state.trim();
    if (clean.isEmpty) return const [];

    final cached = _memoryCache[clean];
    if (cached != null) return cached;

    final merged = <String>{
      ...?_fallbackDistricts[clean],
    };

    try {
      final live = await MarketPriceService.instance.fetchDistricts(clean);
      merged.addAll(live);
    } catch (_) {}

    final result = merged.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    _memoryCache[clean] = result;
    return result;
  }

  static List<String> filterDistricts(
    List<String> districts,
    String query,
  ) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return districts;
    return districts
        .where((district) => district.toLowerCase().contains(q))
        .toList(growable: false);
  }
}
