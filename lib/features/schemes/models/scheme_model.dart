class GovernmentScheme {
  final String id;
  final String name;
  final String description;
  final String category;
  final String eligibility;
  final String benefits;
  final String howToApply;
  final String officialWebsite;
  final String helpline;
  final List<String> documents;
  final String state;
  final bool isCentral;

  const GovernmentScheme({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.eligibility,
    required this.benefits,
    required this.howToApply,
    this.officialWebsite = '',
    this.helpline = '',
    this.documents = const [],
    this.state = '',
    this.isCentral = true,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'description': description,
    'category': category,
    'eligibility': eligibility,
    'benefits': benefits,
    'howToApply': howToApply,
    'officialWebsite': officialWebsite,
    'helpline': helpline,
    'documents': documents,
    'state': state,
    'isCentral': isCentral,
  };

  factory GovernmentScheme.fromMap(Map<String, dynamic> m) => GovernmentScheme(
    id: m['id'] ?? '',
    name: m['name'] ?? '',
    description: m['description'] ?? '',
    category: m['category'] ?? '',
    eligibility: m['eligibility'] ?? '',
    benefits: m['benefits'] ?? '',
    howToApply: m['howToApply'] ?? '',
    officialWebsite: m['officialWebsite'] ?? '',
    helpline: m['helpline'] ?? '',
    documents: List<String>.from(m['documents'] ?? []),
    state: m['state'] ?? '',
    isCentral: m['isCentral'] ?? true,
  );
}

class GovernmentSchemeData {
  static final List<GovernmentScheme> allSchemes = [
    const GovernmentScheme(
      id: 'pmkisan',
      name: 'PM-KISAN',
      description: 'Pradhan Mantri Kisan Samman Nidhi provides income support of Rs. 6,000 per year to small and marginal farmer families through direct benefit transfer.',
      category: 'Income Support',
      eligibility: 'All farmer families with cultivable land. Exclusion: institutional landholders, former/current constitutional post holders, government employees, pensioners.',
      benefits: 'Rs. 6,000 per year in 3 equal instalments of Rs. 2,000 each via Direct Benefit Transfer.',
      howToApply: 'Register at pmkisan.gov.in or visit nearest CSC. Aadhaar and bank account details required.',
      officialWebsite: 'https://pmkisan.gov.in',
      helpline: '155261 / 1800115526',
      documents: ['Aadhaar Card', 'Bank Account Details', 'Land Records'],
      isCentral: true,
    ),
    const GovernmentScheme(
      id: 'pmfby',
      name: 'PM Fasal Bima Yojana',
      description: 'Comprehensive crop insurance scheme to protect farmers against crop loss due to natural calamities, pests and diseases.',
      category: 'Crop Insurance',
      eligibility: 'All farmers including sharecroppers and tenant farmers growing notified crops in notified areas.',
      benefits: 'Full insurance coverage for crop loss. Premium: Kharif 2%, Rabi 1.5%, Commercial/Horticultural 5% of sum insured.',
      howToApply: 'Apply through banks, CSCs, or insurance companies before cut-off date. Last date as notified by state government.',
      officialWebsite: 'https://pmfby.gov.in',
      helpline: '1800-180-1551',
      documents: ['Aadhaar Card', 'Bank Account', 'Land Records/Lease Agreement', 'Crop Sowing Certificate'],
      isCentral: true,
    ),
    const GovernmentScheme(
      id: 'pmkmy',
      name: 'PM Krishi Sinchayee Yojana',
      description: 'Ensures access to water for every farm through micro-irrigation and watershed development.',
      category: 'Irrigation',
      eligibility: 'All farmers. Priority to small and marginal farmers.',
      benefits: '55% subsidy on micro-irrigation for small/marginal farmers, 45% for others. Additional 10% incentive for water-stressed areas.',
      howToApply: 'Apply through state agriculture department or online at pmksy.gov.in.',
      officialWebsite: 'https://pmksy.gov.in',
      helpline: '011-23383838',
      documents: ['Aadhaar Card', 'Land Records', 'Bank Account', 'Borewell/Pump Details'],
      isCentral: true,
    ),
    const GovernmentScheme(
      id: 'pmrwb',
      name: 'PM Kisan Maandhan Yojana',
      description: 'Pension scheme providing Rs. 3,000/month pension after age 60 for small and marginal farmers.',
      category: 'Pension',
      eligibility: 'Small and marginal farmers aged 18-40 with cultivable land up to 2 hectares.',
      benefits: 'Assured monthly pension of Rs. 3,000 after age 60. Government matches contribution.',
      howToApply: 'Register at maandhan.in or nearest CSC. Monthly contribution: Rs. 55 to Rs. 200 based on age.',
      officialWebsite: 'https://maandhan.in',
      helpline: '1800-110-001',
      documents: ['Aadhaar Card', 'Bank Account', 'Land Records', 'Age Proof'],
      isCentral: true,
    ),
    const GovernmentScheme(
      id: 'soil_health',
      name: 'Soil Health Card Scheme',
      description: 'Provides soil health cards to farmers carrying crop-wise recommendations on nutrients and fertilizers.',
      category: 'Soil Health',
      eligibility: 'All farmers across India.',
      benefits: 'Free soil testing and personalized recommendations for fertilizer usage, improving crop yield.',
      howToApply: 'Contact nearest soil testing laboratory or Krishi Vigyan Kendra (KVK).',
      officialWebsite: 'https://soilhealth.dac.gov.in',
      helpline: '011-23383838',
      documents: ['Aadhaar Card', 'Land Records'],
      isCentral: true,
    ),
    const GovernmentScheme(
      id: 'e_nam',
      name: 'e-NAM (Electronic National Agriculture Market)',
      description: 'Online trading platform for agricultural commodities to ensure better price discovery.',
      category: 'Market Access',
      eligibility: 'All farmers, traders, and FPOs registered at mandis.',
      benefits: 'Transparent price discovery, online payment, reduced intermediaries, pan-India market access.',
      howToApply: 'Register at enam.gov.in or at nearest e-NAM enabled mandi.',
      officialWebsite: 'https://enam.gov.in',
      helpline: '1800-180-1551',
      documents: ['Aadhaar Card', 'Bank Account', 'Mandi Registration'],
      isCentral: true,
    ),
    const GovernmentScheme(
      id: 'kcc',
      name: 'Kisan Credit Card',
      description: 'Provides affordable credit to farmers for agricultural and allied activities.',
      category: 'Credit',
      eligibility: 'All farmers, fishers, and animal husbandry farmers.',
      benefits: 'Loan up to Rs. 3 lakh at 4% p.a. (after subvention). Flexible repayment. Insurance coverage.',
      howToApply: 'Apply at nearest bank branch or through PM-KISAN portal.',
      officialWebsite: 'https://www.nabard.org',
      helpline: '1800-11-2500',
      documents: ['Aadhaar Card', 'Land Records', 'Bank Account', 'Passport Photo'],
      isCentral: true,
    ),
    const GovernmentScheme(
      id: 'pmksy_watershed',
      name: 'Watershed Development',
      description: 'Integrated watershed management for sustainable land and water resource management.',
      category: 'Water Conservation',
      eligibility: 'Rainfed areas with degraded land. Priority to tribal and drought-prone areas.',
      benefits: 'Funding for ridge to valley treatment, moisture conservation, and livelihood activities.',
      howToApply: 'Apply through state watershed departments or district collectorate.',
      officialWebsite: 'https://pmksy.gov.in',
      helpline: '011-23383838',
      documents: ['Land Records', 'Aadhaar Card', 'Bank Account'],
      isCentral: true,
    ),
    const GovernmentScheme(
      id: 'paramparagat',
      name: 'Paramparagat Krishi Vikas Yojana',
      description: 'Promotes organic farming through cluster approach and PGS certification.',
      category: 'Organic Farming',
      eligibility: 'Farmers in clusters of 50+ farmers covering at least 50 acres.',
      benefits: 'Rs. 50,000/hectare for 3 years including Rs. 31,000 for organic inputs and certification.',
      howToApply: 'Apply through district agriculture officer or state organic mission.',
      officialWebsite: 'https://pgsindia-ncof.gov.in',
      helpline: '011-23383838',
      documents: ['Aadhaar Card', 'Land Records', 'Bank Account', 'Cluster Registration'],
      isCentral: true,
    ),
    const GovernmentScheme(
      id: 'svamitva',
      name: 'SVAMITVA Yojana',
      description: 'Drones-based survey to map rural inhabited lands and issue property cards.',
      category: 'Land Records',
      eligibility: 'Owners of rural inhabited land properties.',
      benefits: 'Legal ownership document (Property Card) enabling access to credit and resolving disputes.',
      howToApply: 'Contact village revenue officer or visit SVAMITVA survey camps.',
      officialWebsite: 'https://svamitva.nic.in',
      helpline: '011-23063614',
      documents: ['Aadhaar Card', 'Land Records', 'Revenue Records'],
      isCentral: true,
    ),
    const GovernmentScheme(
      id: 'state_rythu',
      name: 'Rythu Bandhu / State Investment Support',
      description: 'Direct investment support to farmers for every season (varies by state). Telangana Rythu Bandhu, Maharashtra etc.',
      category: 'Income Support',
      eligibility: 'Land-owning farmers (varies by state).',
      benefits: 'Rs. 5,000-10,000 per acre per season as direct investment support.',
      howToApply: 'Register through state agriculture department or bank.',
      documents: ['Aadhaar Card', 'Land Records', 'Bank Account'],
      state: 'State Specific',
      isCentral: false,
    ),
    const GovernmentScheme(
      id: 'pmfme',
      name: 'PM Formalisation of Micro Food Processing Enterprises',
      description: 'Supports unorganized micro food processing enterprises with credit and infrastructure.',
      category: 'Food Processing',
      eligibility: 'Existing unorganized micro food processing enterprises.',
      benefits: 'Credit linked subsidy of 35% with ceiling of Rs. 10 lakh. Free training and handholding.',
      howToApply: 'Apply at pmfme.ditol.gov.in or through district industries center.',
      documents: ['Aadhaar Card', 'Business Registration', 'Bank Account', 'Food License'],
      isCentral: true,
    ),
  ];

  static List<GovernmentScheme> getByCategory(String category) {
    if (category == 'All') return allSchemes;
    return allSchemes.where((s) => s.category == category).toList();
  }

  static List<GovernmentScheme> search(String query) {
    final q = query.toLowerCase();
    return allSchemes.where((s) =>
      s.name.toLowerCase().contains(q) ||
      s.description.toLowerCase().contains(q) ||
      s.category.toLowerCase().contains(q) ||
      s.eligibility.toLowerCase().contains(q)
    ).toList();
  }

  static List<String> get categories =>
      ['All'] + allSchemes.map((s) => s.category).toSet().toList();
}
