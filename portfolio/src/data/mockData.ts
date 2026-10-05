/**
 * Authentic Mock & Demonstration Datasets for VidhAI Interactive Experiences
 * 
 * Note: All simulated responses, prices, and crops adhere strictly to the
 * schemas and logic implemented in VidhAI source code.
 */

export interface AiChatPrompt {
  id: string;
  prompt: string;
  farmContext: {
    farmName: string;
    size: string;
    district: string;
    soil: string;
    activeCrop: string;
  };
  routedModel: string;
  tier: string;
  provider: 'Groq (openai/gpt-oss-20b)' | 'NVIDIA NIM (nemotron-3-ultra-550b)';
  response: string;
}

export const AI_CHAT_SCENARIOS: AiChatPrompt[] = [
  {
    id: 'crop-recommendation',
    prompt: 'What crop best fits my farm for this upcoming season?',
    farmContext: {
      farmName: 'Green Valley Farm',
      size: '2.5 Acres',
      district: 'Tiruppur, Tamil Nadu',
      soil: 'Red Loamy',
      activeCrop: 'Fallow (Post-Maize)',
    },
    routedModel: 'Nemotron Ultra 550B via AI Router',
    tier: 'Main Agronomic Reasoning',
    provider: 'NVIDIA NIM (nemotron-3-ultra-550b)',
    response: `Based on your **2.5 acre red loamy soil** in Tiruppur and following your recent maize harvest:

1. **Top Recommendation: Hybrid Tomato (Shivam / US-440)**
   - **Suitability Score**: 94% match
   - **Agronomic Fit**: Red loamy soil offers excellent root aeration and drainage. Follows maize effectively with low nematode crossover.
   - **Mandi Synergy**: Local Tiruppur & Coimbatore mandis currently record steady demand at ₹24–28/kg.
   - **Water Requirement**: Medium (Drip irrigation highly recommended for water efficiency).

2. **Secondary Consideration: Groundnut (VRI-8)**
   - Excellent nitrogen restoration for soil following cereal rotation. Low pest carryover risk.

Would you like me to generate a 90-day task and fertilizer schedule for Hybrid Tomato?`,
  },
  {
    id: 'rain-prep',
    prompt: 'Heavy rain is forecasted in 24 hours. What precautions should I take for my tomato field?',
    farmContext: {
      farmName: 'Green Valley Farm',
      size: '2.5 Acres',
      district: 'Tiruppur, Tamil Nadu',
      soil: 'Red Loamy',
      activeCrop: 'Tomato (Flowering Stage)',
    },
    routedModel: 'openai/gpt-oss-20b via Groq',
    tier: 'Fast Conversational',
    provider: 'Groq (openai/gpt-oss-20b)',
    response: `Open-Meteo telemetry shows **38mm precipitation** expected over the next 24 hours in Tiruppur. Because your tomatoes are in the sensitive **Flowering Stage**, take these immediate actions:

- **Drainage Channels**: Clear tertiary furrows immediately to prevent standing water around root zones. Red loamy soil drains reasonably well, but waterlogging over 6 hours induces blossom drop and root asphyxiation.
- **Suspend Spraying & Fertigation**: Cease all foliar nitrogen and systemic pesticide applications until rain clears to avoid chemical runoff and economic waste.
- **Post-Rain Fungicide Buffer**: Keep Mancozeb (2g/L) or Copper Oxychloride ready for a protective preventive spray within 24 hours post-downpour to inhibit Early Blight (Alternaria solani).
- **Physical Staking**: Check trellis and stake ties on windward rows.

I have logged an automated reminder for post-rain field inspection.`,
  },
  {
    id: 'mandi-analysis',
    prompt: 'Explain the recent modal price trends for Green Chilli in our district.',
    farmContext: {
      farmName: 'Green Valley Farm',
      size: '2.5 Acres',
      district: 'Tiruppur, Tamil Nadu',
      soil: 'Red Loamy',
      activeCrop: 'Tomato / Chilli',
    },
    routedModel: 'openai/gpt-oss-20b via Groq',
    tier: 'Fast Conversational',
    provider: 'Groq (openai/gpt-oss-20b)',
    response: `According to normalized **AGMARKNET 2.0 records** for Tiruppur and neighboring Dindigul markets:

- **Current Modal Price**: **₹42.00 / kg** (up from ₹34.50/kg seven days ago; +21.7%).
- **Arrival Volumes**: Daily reported arrivals dropped by 18% across Western Tamil Nadu mandis due to localized moisture during picking.
- **Quality Premium**: G-4 and Teja varieties with uniform green luster are fetching up to ₹48.00/kg at morning auctions.
- **Strategic Advice**: If you have harvestable yield, schedule picking for tomorrow morning to capitalize on current wholesale tightness before weekend arrivals pick up.`,
  },
  {
    id: 'farm-tasks',
    prompt: "What are my farm's priority duties for this morning?",
    farmContext: {
      farmName: 'Green Valley Farm',
      size: '2.5 Acres',
      district: 'Tiruppur, Tamil Nadu',
      soil: 'Red Loamy',
      activeCrop: 'Tomato (Day 34)',
    },
    routedModel: 'openai/gpt-oss-20b via Groq',
    tier: 'Fast Conversational',
    provider: 'Groq (openai/gpt-oss-20b)',
    response: `Here are your high-priority items based on your **Tomato Day 34** lifecycle and weather outlook:

1. **Morning Drip fertigation (07:00 – 08:30 AM)**
   - Dose: 19:19:19 NPK soluble fertilizer (2.5 kg/acre) to sustain early vegetative vigor.
2. **Sucker Pruning / Desuckering**
   - Pinch off lower auxiliary ground shoots below the first flower cluster to direct energy to the main stem.
3. **Pheromone Trap Inspection**
   - Check the 4 Helicoverpa armigera lure traps placed along field perimeters. Threshold: > 5 moths/trap requires bio-pesticide spray.

All items are synced with your **Tasks** tab. Marked tasks automatically update your expense log.`,
  },
];

export interface CropRecommendationItem {
  id: string;
  name: string;
  scientificName: string;
  category: 'Vegetables' | 'Pulses' | 'Oilseeds' | 'Cereals' | 'Cash Crops';
  suitabilityScore: number;
  durationDays: string;
  waterRequirement: 'Low' | 'Medium' | 'High';
  riskLevel: 'Low' | 'Moderate' | 'High';
  estimatedCostPerAcre: number;
  expectedYieldQuintal: string;
  agronomicReasoning: string;
  marketSynergy: string;
}

export const MOCK_CROP_RECOMMENDATIONS: CropRecommendationItem[] = [
  {
    id: 'crop-1',
    name: 'Hybrid Tomato (Shivam)',
    scientificName: 'Solanum lycopersicum',
    category: 'Vegetables',
    suitabilityScore: 94,
    durationDays: '100–120 Days',
    waterRequirement: 'Medium',
    riskLevel: 'Moderate',
    estimatedCostPerAcre: 38000,
    expectedYieldQuintal: '200–250 Quintals/Acre',
    agronomicReasoning: 'Flourishes in well-drained red loam. Ideal companion after cereal rotations.',
    marketSynergy: 'Consistent high volume demand in regional mandis with rapid turnover cycles.',
  },
  {
    id: 'crop-2',
    name: 'Groundnut (VRI-8)',
    scientificName: 'Arachis hypogaea',
    category: 'Oilseeds',
    suitabilityScore: 91,
    durationDays: '105–115 Days',
    waterRequirement: 'Low',
    riskLevel: 'Low',
    estimatedCostPerAcre: 22000,
    expectedYieldQuintal: '12–16 Quintals/Acre',
    agronomicReasoning: 'Fixes atmospheric nitrogen into the soil, improving fertility for subsequent crops.',
    marketSynergy: 'Assured minimum support pricing and steady industrial oilseed mill procurement.',
  },
  {
    id: 'crop-3',
    name: 'Green Chilli (G-4)',
    scientificName: 'Capsicum annuum',
    category: 'Vegetables',
    suitabilityScore: 88,
    durationDays: '140–160 Days',
    waterRequirement: 'Medium',
    riskLevel: 'Moderate',
    estimatedCostPerAcre: 32000,
    expectedYieldQuintal: '70–90 Quintals/Acre',
    agronomicReasoning: 'Tolerates fluctuating temperatures and produces continuous flushes over 4 months.',
    marketSynergy: 'Premium wholesale prices with active interstate transit demand.',
  },
  {
    id: 'crop-4',
    name: 'Maize (Hybrid Pioneer)',
    scientificName: 'Zea mays',
    category: 'Cereals',
    suitabilityScore: 85,
    durationDays: '95–105 Days',
    waterRequirement: 'Medium',
    riskLevel: 'Low',
    estimatedCostPerAcre: 18000,
    expectedYieldQuintal: '28–35 Quintals/Acre',
    agronomicReasoning: 'Heavy feeder with rapid vegetative establishment. Highly responsive to balanced NPK.',
    marketSynergy: 'Strong local poultry feed demand with instant cash settlement at local procurement hubs.',
  },
  {
    id: 'crop-5',
    name: 'Black Gram / Urad (VBN-8)',
    scientificName: 'Vigna mungo',
    category: 'Pulses',
    suitabilityScore: 82,
    durationDays: '65–75 Days',
    waterRequirement: 'Low',
    riskLevel: 'Low',
    estimatedCostPerAcre: 12000,
    expectedYieldQuintal: '4–6 Quintals/Acre',
    agronomicReasoning: 'Short duration catch crop ideal for filling fallow gaps while building soil organic matter.',
    marketSynergy: 'High pulse market prices with low storage degradation risk.',
  },
  {
    id: 'crop-6',
    name: 'Cotton (Bt RCH-2)',
    scientificName: 'Gossypium hirsutum',
    category: 'Cash Crops',
    suitabilityScore: 78,
    durationDays: '150–165 Days',
    waterRequirement: 'Medium',
    riskLevel: 'High',
    estimatedCostPerAcre: 42000,
    expectedYieldQuintal: '10–14 Quintals/Acre',
    agronomicReasoning: 'Deep taproot system accesses deeper subsoil moisture; requires vigilant bollworm monitoring.',
    marketSynergy: 'Tiruppur textile hub proximity offers direct mill gate procurement options.',
  },
];

export interface MandiRecord {
  commodity: string;
  variety: string;
  state: string;
  district: string;
  market: string;
  minPricePerKg: number;
  modalPricePerKg: number;
  maxPricePerKg: number;
  arrivalKg: number;
  date: string;
  trend: 'up' | 'down' | 'steady';
  history7Days: { day: string; price: number }[];
}

export const MOCK_MANDI_DATA: MandiRecord[] = [
  {
    commodity: 'Tomato',
    variety: 'Hybrid US-440',
    state: 'Tamil Nadu',
    district: 'Tiruppur',
    market: 'Tiruppur Central Market',
    minPricePerKg: 20.0,
    modalPricePerKg: 24.5,
    maxPricePerKg: 28.0,
    arrivalKg: 14200,
    date: 'Today',
    trend: 'up',
    history7Days: [
      { day: 'Day -6', price: 19.5 },
      { day: 'Day -5', price: 21.0 },
      { day: 'Day -4', price: 22.0 },
      { day: 'Day -3', price: 21.5 },
      { day: 'Day -2', price: 23.0 },
      { day: 'Day -1', price: 24.0 },
      { day: 'Today', price: 24.5 },
    ],
  },
  {
    commodity: 'Onion',
    variety: 'Nashik Red',
    state: 'Maharashtra',
    district: 'Nashik',
    market: 'Lasalgaon Mandi',
    minPricePerKg: 26.0,
    modalPricePerKg: 31.0,
    maxPricePerKg: 35.5,
    arrivalKg: 85000,
    date: 'Today',
    trend: 'up',
    history7Days: [
      { day: 'Day -6', price: 25.0 },
      { day: 'Day -5', price: 26.5 },
      { day: 'Day -4', price: 28.0 },
      { day: 'Day -3', price: 29.5 },
      { day: 'Day -2', price: 30.0 },
      { day: 'Day -1', price: 30.5 },
      { day: 'Today', price: 31.0 },
    ],
  },
  {
    commodity: 'Green Chilli',
    variety: 'G-4 Green',
    state: 'Tamil Nadu',
    district: 'Coimbatore',
    market: 'Mettupalayam Market',
    minPricePerKg: 38.0,
    modalPricePerKg: 42.0,
    maxPricePerKg: 48.0,
    arrivalKg: 9500,
    date: 'Today',
    trend: 'up',
    history7Days: [
      { day: 'Day -6', price: 34.5 },
      { day: 'Day -5', price: 36.0 },
      { day: 'Day -4', price: 37.5 },
      { day: 'Day -3', price: 39.0 },
      { day: 'Day -2', price: 40.0 },
      { day: 'Day -1', price: 41.5 },
      { day: 'Today', price: 42.0 },
    ],
  },
  {
    commodity: 'Cotton',
    variety: 'Medium Staple',
    state: 'Gujarat',
    district: 'Rajkot',
    market: 'Gondal Mandi',
    minPricePerKg: 68.0,
    modalPricePerKg: 73.5,
    maxPricePerKg: 78.0,
    arrivalKg: 42000,
    date: 'Today',
    trend: 'steady',
    history7Days: [
      { day: 'Day -6', price: 72.0 },
      { day: 'Day -5', price: 73.0 },
      { day: 'Day -4', price: 72.5 },
      { day: 'Day -3', price: 73.0 },
      { day: 'Day -2', price: 73.5 },
      { day: 'Day -1', price: 73.0 },
      { day: 'Today', price: 73.5 },
    ],
  },
  {
    commodity: 'Wheat',
    variety: 'Sharbati Quality',
    state: 'Madhya Pradesh',
    district: 'Sehore',
    market: 'Sehore Mandi',
    minPricePerKg: 28.5,
    modalPricePerKg: 32.0,
    maxPricePerKg: 36.0,
    arrivalKg: 62000,
    date: 'Today',
    trend: 'steady',
    history7Days: [
      { day: 'Day -6', price: 31.5 },
      { day: 'Day -5', price: 32.0 },
      { day: 'Day -4', price: 32.0 },
      { day: 'Day -3', price: 31.8 },
      { day: 'Day -2', price: 32.2 },
      { day: 'Day -1', price: 32.0 },
      { day: 'Today', price: 32.0 },
    ],
  },
];

export const MOCK_COMMUNITY_MATCH = {
  harvest: {
    author: 'DEMO FARMER',
    role: 'Verified Farmer (Illustrative)',
    district: 'Tiruppur, TN',
    crop: 'Tomato (Hybrid US-440)',
    quantityKg: 200,
    harvestInDays: 8,
    askingPricePerKg: 24.0,
    category: 'available_soon',
    status: 'active',
    interestedBuyers: 4,
    notes: 'Illustrative Scenario: Grade-A produce, picked with drip fertigation, zero chemical residue in last 15 days.',
  },
  demand: {
    author: 'DEMO BUYER',
    role: 'Direct Consumer / Retailer (Illustrative)',
    district: 'Tiruppur, TN',
    crop: 'Tomato',
    requiredKg: 150,
    targetDate: 'Within 10 days',
    targetPricePerKg: 23.5,
    category: 'demand',
    status: 'active',
    availableSuppliers: 3,
    notes: 'Illustrative Scenario: Need regular delivery for weekly organic box subscriptions.',
  },
  matchingMetrics: {
    locationMatch: 'Same District (Tiruppur)',
    quantityFeasibility: '150 kg requested within 200 kg supply',
    priceGap: '₹0.50 / kg spread (Ready for direct negotiation)',
    disintermediationBenefit: 'Farmer gains +18% over local middleman; Buyer saves 12% over distributor retail.',
  },
};

export const MULTILINGUAL_DEMO_TEXTS: Record<
  string,
  {
    greeting: string;
    tagline: string;
    cta: string;
    weatherCondition: string;
    activeFarmLabel: string;
    recommendationTitle: string;
  }
> = {
  en: {
    greeting: 'Welcome to VidhAI',
    tagline: 'Intelligence for Every Field',
    cta: 'Explore Platform',
    weatherCondition: 'Clear skies, 28°C',
    activeFarmLabel: 'Active Farm: 2.5 Acres',
    recommendationTitle: 'Top Recommended Crop: Tomato',
  },
  ta: {
    greeting: 'விதை AI-க்கு நல்வரவு',
    tagline: 'ஒவ்வொரு வயலுக்கும் உன்னத நுண்ணறிவு',
    cta: 'பயன்பாட்டை காண்க',
    weatherCondition: 'தெளிவான வானிலை, 28°C',
    activeFarmLabel: 'செயலில் உள்ள நிலம்: 2.5 ஏக்கர்',
    recommendationTitle: 'சிறந்த பயிர் பரிந்துரை: தக்காளி',
  },
  hi: {
    greeting: 'विधAI में आपका स्वागत है',
    tagline: 'हर खेत के लिए सटीक बुद्धिमत्ता',
    cta: 'मंच देखें',
    weatherCondition: 'साफ मौसम, 28°C',
    activeFarmLabel: 'सक्रिय खेत: 2.5 एकड़',
    recommendationTitle: 'शीर्ष अनुशंसित फसल: टमाटर',
  },
  te: {
    greeting: 'విధAI కి స్వాగతం',
    tagline: 'ప్రతి పొలానికి సాంకేతిక మేధస్సు',
    cta: 'వేదికను అన్వేషించండి',
    weatherCondition: 'నిర్మలమైన ఆకాశం, 28°C',
    activeFarmLabel: 'క్రియాశీల పొలం: 2.5 ఎకరాలు',
    recommendationTitle: 'అత్యుత్తమ పంట సిఫార్సు: టమోటా',
  },
  ur: {
    greeting: 'ودھAI میں خوش آمدید',
    tagline: 'ہر کھیت کے لیے جدید ترین ذہانت',
    cta: 'پلیٹ فارم دیکھیں',
    weatherCondition: 'صاف موسم، 28 ڈگری سینٹی گریڈ',
    activeFarmLabel: 'فعال کھیت: 2.5 ایکڑ',
    recommendationTitle: 'بہترین تجویز کردہ فصل: ٹماٹر',
  },
};
