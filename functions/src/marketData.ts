/**
 * VidhAI market-data reference layer.
 *
 * Administrative hierarchy data only (NOT invented pricing):
 *  - The complete list of Indian States / UTs and their districts,
 *    compiled from official Govt. of India administrative references.
 *  - Unit -> kg conversion rules used to normalise reported mandi prices
 *    to a reliable per-kilogram value. Unknown units are reported
 *    explicitly as "Price unit unavailable" rather than guessed.
 *
 * Actual market PRICES never live in this file; they are fetched by the
 * MarketPriceProvider (mandi-api / AGMARKNET data.gov.in aggregator) at
 * request time and cached in Firestore.
 */

export interface IndiaStateInfo {
  id: string;
  name: string;
  ut: boolean;
  districts: string[];
}

const _d = (...names: string[]): string[] => names;

// ── States / UTs + district lists (administrative facts) ────────────────────

export const INDIAN_STATES: IndiaStateInfo[] = [
  {
    id: 'andhra-pradesh',
    name: 'Andhra Pradesh',
    ut: false,
    districts: _d('Anantapur', 'Chittoor', 'East Godavari', 'Guntur', 'Krishna', 'Kurnool', 'Prakasam', 'SPSR Nellore', 'Srikakulam', 'Visakhapatnam', 'Vizianagaram', 'West Godavari', 'YSR Kadapa'),
  },
  {
    id: 'arunachal-pradesh',
    name: 'Arunachal Pradesh',
    ut: false,
    districts: _d('Tawang', 'West Kameng', 'East Kameng', 'Papum Pare', 'Kurung Kumey', 'Kra Daadi', 'Lower Subansiri', 'Upper Subansiri', 'West Siang', 'East Siang', 'Siang', 'Upper Siang', 'Lower Dibang Valley', 'Dibang Valley', 'Lohit', 'Anjaw', 'Namsai', 'Changlang', 'Tirap', 'Longding'),
  },
  {
    id: 'assam',
    name: 'Assam',
    ut: false,
    districts: _d('Baksa', 'Barpeta', 'Biswanath', 'Bongaigaon', 'Cachar', 'Charaideo', 'Chirang', 'Darrang', 'Dhemaji', 'Dhubri', 'Dibrugarh', 'Dima Hasao', 'Goalpara', 'Golaghat', 'Hailakandi', 'Hojai', 'Jorhat', 'Kamrup', 'Kamrup Metropolitan', 'Karbi Anglong', 'Karimganj', 'Kokrajhar', 'Lakhimpur', 'Majuli', 'Morigaon', 'Nagaon', 'Nalbari', 'Sivasagar', 'Sonitpur', 'South Salmara-Mankachar', 'Tinsukia', 'Udalguri', 'West Karbi Anglong'),
  },
  {
    id: 'bihar',
    name: 'Bihar',
    ut: false,
    districts: _d('Araria', 'Arwal', 'Aurangabad', 'Banka', 'Begusarai', 'Bhagalpur', 'Bhojpur', 'Buxar', 'Darbhanga', 'East Champaran', 'Gaya', 'Gopalganj', 'Jamui', 'Jehanabad', 'Kaimur', 'Katihar', 'Khagaria', 'Kishanganj', 'Lakhisarai', 'Madhepura', 'Madhubani', 'Munger', 'Muzaffarpur', 'Nalanda', 'Nawada', 'Patna', 'Purnia', 'Rohtas', 'Saharsa', 'Samastipur', 'Saran', 'Sheikhpura', 'Sheohar', 'Sitamarhi', 'Siwan', 'Supaul', 'Vaishali', 'West Champaran'),
  },
  {
    id: 'chhattisgarh',
    name: 'Chhattisgarh',
    ut: false,
    districts: _d('Balod', 'Baloda Bazar', 'Balrampur', 'Bastar', 'Bemetara', 'Bijapur', 'Bilaspur', 'Dantewada', 'Dhamtari', 'Durg', 'Gariaband', 'Gaurela-Pendra-Marwahi', 'Janjgir-Champa', 'Jashpur', 'Kabirdham', 'Kanker', 'Kondagaon', 'Korba', 'Koriya', 'Mahasamund', 'Mungeli', 'Narayanpur', 'Raigarh', 'Raipur', 'Rajnandgaon', 'Sukma', 'Surajpur', 'Surguja'),
  },
  {
    id: 'goa',
    name: 'Goa',
    ut: false,
    districts: _d('North Goa', 'South Goa'),
  },
  {
    id: 'gujarat',
    name: 'Gujarat',
    ut: false,
    districts: _d('Ahmedabad', 'Amreli', 'Anand', 'Aravalli', 'Banaskantha', 'Bharuch', 'Bhavnagar', 'Botad', 'Chhota Udaipur', 'Dahod', 'Dang', 'Devbhoomi Dwarka', 'Gandhinagar', 'Gir Somnath', 'Jamnagar', 'Junagadh', 'Kachchh', 'Kheda', 'Mahisagar', 'Mehsana', 'Morbi', 'Narmada', 'Navsari', 'Panchmahal', 'Patan', 'Porbandar', 'Rajkot', 'Sabarkantha', 'Surat', 'Surendranagar', 'Tapi', 'Vadodara', 'Valsad'),
  },
  {
    id: 'haryana',
    name: 'Haryana',
    ut: false,
    districts: _d('Ambala', 'Bhiwani', 'Charkhi Dadri', 'Faridabad', 'Fatehabad', 'Gurugram', 'Hisar', 'Jhajjar', 'Jind', 'Kaithal', 'Karnal', 'Kurukshetra', 'Mahendragarh', 'Nuh', 'Palwal', 'Panchkula', 'Panipat', 'Rewari', 'Rohtak', 'Sirsa', 'Sonipat', 'Yamunanagar'),
  },
  {
    id: 'himachal-pradesh',
    name: 'Himachal Pradesh',
    ut: false,
    districts: _d('Bilaspur', 'Chamba', 'Hamirpur', 'Kangra', 'Kinnaur', 'Kullu', 'Lahaul and Spiti', 'Mandi', 'Shimla', 'Sirmaur', 'Solan', 'Una'),
  },
  {
    id: 'jharkhand',
    name: 'Jharkhand',
    ut: false,
    districts: _d('Bokaro', 'Chatra', 'Deoghar', 'Dhanbad', 'Dumka', 'East Singhbhum', 'Garhwa', 'Giridih', 'Godda', 'Gumla', 'Hazaribagh', 'Jamtara', 'Khunti', 'Koderma', 'Latehar', 'Lohardaga', 'Pakur', 'Palamu', 'Ramgarh', 'Ranchi', 'Sahibganj', 'Seraikela-Kharsawan', 'Simdega', 'West Singhbhum'),
  },
  {
    id: 'karnataka',
    name: 'Karnataka',
    ut: false,
    districts: _d('Bagalkot', 'Ballari', 'Belagavi', 'Bengaluru Rural', 'Bengaluru Urban', 'Bidar', 'Chamarajanagar', 'Chikkaballapur', 'Chikkamagaluru', 'Chitradurga', 'Dakshina Kannada', 'Davanagere', 'Dharwad', 'Gadag', 'Hassan', 'Haveri', 'Kalaburagi', 'Kodagu', 'Kolar', 'Koppal', 'Mandya', 'Mysuru', 'Raichur', 'Ramanagara', 'Shivamogga', 'Tumakuru', 'Udupi', 'Uttara Kannada', 'Vijayapura', 'Yadgir'),
  },
  {
    id: 'kerala',
    name: 'Kerala',
    ut: false,
    districts: _d('Alappuzha', 'Ernakulam', 'Idukki', 'Kannur', 'Kasaragod', 'Kollam', 'Kottayam', 'Kozhikode', 'Malappuram', 'Palakkad', 'Pathanamthitta', 'Thiruvananthapuram', 'Thrissur', 'Wayanad'),
  },
  {
    id: 'madhya-pradesh',
    name: 'Madhya Pradesh',
    ut: false,
    districts: _d('Agar Malwa', 'Alirajpur', 'Anuppur', 'Ashoknagar', 'Balaghat', 'Barwani', 'Betul', 'Bhind', 'Bhopal', 'Burhanpur', 'Chhatarpur', 'Chhindwara', 'Damoh', 'Datia', 'Dewas', 'Dhar', 'Dindori', 'Guna', 'Gwalior', 'Harda', 'Hoshangabad', 'Indore', 'Jabalpur', 'Jhabua', 'Katni', 'Khandwa', 'Khargone', 'Mandla', 'Mandsaur', 'Morena', 'Narmadapuram', 'Narsinghpur', 'Neemuch', 'Niwari', 'Panna', 'Raisen', 'Rajgarh', 'Ratlam', 'Rewa', 'Sagar', 'Satna', 'Sehore', 'Seoni', 'Shahdol', 'Shajapur', 'Sheopur', 'Shivpuri', 'Sidhi', 'Singrauli', 'Tikamgarh', 'Ujjain', 'Umaria', 'Vidisha'),
  },
  {
    id: 'maharashtra',
    name: 'Maharashtra',
    ut: false,
    districts: _d('Ahmadnagar', 'Akola', 'Amravati', 'Aurangabad', 'Beed', 'Bhandara', 'Buldhana', 'Chandrapur', 'Chhatrapati Sambhajinagar', 'Dhule', 'Gadchiroli', 'Gondia', 'Hingoli', 'Jalgaon', 'Jalna', 'Kolhapur', 'Latur', 'Mumbai City', 'Mumbai Suburban', 'Nagpur', 'Nanded', 'Nandurbar', 'Nashik', 'Osmanabad', 'Palghar', 'Parbhani', 'Pune', 'Raigad', 'Ratnagiri', 'Sangli', 'Satara', 'Sindhudurg', 'Solapur', 'Thane', 'Wardha', 'Washim', 'Yavatmal'),
  },
  {
    id: 'manipur',
    name: 'Manipur',
    ut: false,
    districts: _d('Bishnupur', 'Chandel', 'Churachandpur', 'Imphal East', 'Imphal West', 'Jiribam', 'Kakching', 'Kamjong', 'Kangpokpi', 'Noney', 'Pherzawl', 'Senapati', 'Tamenglong', 'Tengnoupal', 'Thoubal', 'Ukhrul'),
  },
  {
    id: 'meghalaya',
    name: 'Meghalaya',
    ut: false,
    districts: _d('East Garo Hills', 'East Jaintia Hills', 'East Khasi Hills', 'North Garo Hills', 'Ri Bhoi', 'South Garo Hills', 'South West Garo Hills', 'South West Khasi Hills', 'West Garo Hills', 'West Jaintia Hills', 'West Khasi Hills'),
  },
  {
    id: 'mizoram',
    name: 'Mizoram',
    ut: false,
    districts: _d('Aizawl', 'Champhai', 'Hnahthial', 'Khawzawl', 'Kolasib', 'Lawngtlai', 'Lunglei', 'Mamit', 'Saiha', 'Saitual', 'Serchhip'),
  },
  {
    id: 'nagaland',
    name: 'Nagaland',
    ut: false,
    districts: _d('Chumoukedima', 'Dimapur', 'Kiphire', 'Kohima', 'Longleng', 'Mokokchung', 'Mon', 'Niuland', 'Noklak', 'Peren', 'Phek', 'Shamator', 'Tseminyu', 'Tuensang', 'Wokha', 'Zunheboto'),
  },
  {
    id: 'odisha',
    name: 'Odisha',
    ut: false,
    districts: _d('Angul', 'Balangir', 'Balasore', 'Bargarh', 'Bhadrak', 'Boudh', 'Cuttack', 'Debagarh', 'Dhenkanal', 'Gajapati', 'Ganjam', 'Jagatsinghpur', 'Jajpur', 'Jharsuguda', 'Kalahandi', 'Kandhamal', 'Kendrapara', 'Kendujhar', 'Khordha', 'Koraput', 'Malkangiri', 'Mayurbhanj', 'Nabarangpur', 'Nayagarh', 'Nuapada', 'Puri', 'Rayagada', 'Sambalpur', 'Subarnapur', 'Sundargarh'),
  },
  {
    id: 'punjab',
    name: 'Punjab',
    ut: false,
    districts: _d('Amritsar', 'Barnala', 'Bathinda', 'Faridkot', 'Fatehgarh Sahib', 'Fazilka', 'Firozpur', 'Gurdaspur', 'Hoshiarpur', 'Jalandhar', 'Kapurthala', 'Ludhiana', 'Mansa', 'Moga', 'Muktsar', 'Pathankot', 'Patiala', 'Rupnagar', 'Sahibzada Ajit Singh Nagar', 'Sangrur', 'Shahid Bhagat Singh Nagar', 'Tarn Taran'),
  },
  {
    id: 'rajasthan',
    name: 'Rajasthan',
    ut: false,
    districts: _d('Ajmer', 'Alwar', 'Banswara', 'Baran', 'Barmer', 'Bharatpur', 'Bhilwara', 'Bikaner', 'Bundi', 'Chittorgarh', 'Churu', 'Dausa', 'Dholpur', 'Dungarpur', 'Hanumangarh', 'Jaipur', 'Jaisalmer', 'Jalore', 'Jhalawar', 'Jhunjhunu', 'Jodhpur', 'Karauli', 'Kota', 'Nagaur', 'Pali', 'Pratapgarh', 'Rajsamand', 'Sawai Madhopur', 'Sikar', 'Sirohi', 'Sri Ganganagar', 'Tonk', 'Udaipur'),
  },
  {
    id: 'sikkim',
    name: 'Sikkim',
    ut: false,
    districts: _d('Gangtok', 'Gyalshing', 'Mangan', 'Namchi', 'Pakyong', 'Soreng'),
  },
  {
    id: 'tamil-nadu',
    name: 'Tamil Nadu',
    ut: false,
    districts: _d('Ariyalur', 'Chengalpattu', 'Chennai', 'Coimbatore', 'Cuddalore', 'Dharmapuri', 'Dindigul', 'Erode', 'Kallakurichi', 'Kanchipuram', 'Kanyakumari', 'Karur', 'Krishnagiri', 'Madurai', 'Mayiladuthurai', 'Nagapattinam', 'Namakkal', 'Nilgiris', 'Perambalur', 'Pudukkottai', 'Ramanathapuram', 'Ranipet', 'Salem', 'Sivaganga', 'Tenkasi', 'Thanjavur', 'Theni', 'Thoothukudi', 'Tiruchirappalli', 'Tirunelveli', 'Tirupathur', 'Tiruppur', 'Tiruvallur', 'Tiruvannamalai', 'Tiruvarur', 'Vellore', 'Viluppuram', 'Virudhunagar'),
  },
  {
    id: 'telangana',
    name: 'Telangana',
    ut: false,
    districts: _d('Adilabad', 'Bhadradri Kothagudem', 'Hyderabad', 'Jagtial', 'Jangaon', 'Jayashankar Bhupalpally', 'Jogulamba Gadwal', 'Kamareddy', 'Karimnagar', 'Khammam', 'Komaram Bheem', 'Mahabubabad', 'Mahabubnagar', 'Mancherial', 'Medak', 'Medchal-Malkajgiri', 'Mulugu', 'Nagarkurnool', 'Nalgonda', 'Narayanpet', 'Nirmal', 'Nizamabad', 'Peddapalli', 'Rajanna Sircilla', 'Ranga Reddy', 'Sangareddy', 'Siddipet', 'Suryapet', 'Vikarabad', 'Wanaparthy', 'Warangal Rural', 'Warangal Urban', 'Yadadri Bhuvanagiri'),
  },
  {
    id: 'tripura',
    name: 'Tripura',
    ut: false,
    districts: _d('Dhalai', 'Gomati', 'Khowai', 'North Tripura', 'Sepahijala', 'South Tripura', 'Unakoti', 'West Tripura'),
  },
  {
    id: 'uttar-pradesh',
    name: 'Uttar Pradesh',
    ut: false,
    districts: _d('Agra', 'Aligarh', 'Ambedkar Nagar', 'Amethi', 'Amroha', 'Auraiya', 'Ayodhya', 'Azamgarh', 'Baghpat', 'Bahraich', 'Ballia', 'Balrampur', 'Banda', 'Barabanki', 'Bareilly', 'Basti', 'Bhadohi', 'Bijnor', 'Budaun', 'Bulandshahr', 'Chandauli', 'Chitrakoot', 'Deoria', 'Etah', 'Etawah', 'Farrukhabad', 'Fatehpur', 'Firozabad', 'Gautam Buddha Nagar', 'Ghaziabad', 'Ghazipur', 'Gonda', 'Gorakhpur', 'Hamirpur', 'Hapur', 'Hardoi', 'Hathras', 'Jalaun', 'Jaunpur', 'Jhansi', 'Kannauj', 'Kanpur Dehat', 'Kanpur Nagar', 'Kasganj', 'Kaushambi', 'Kushinagar', 'Lakhimpur Kheri', 'Lalitpur', 'Lucknow', 'Maharajganj', 'Mahoba', 'Mainpuri', 'Mathura', 'Mau', 'Meerut', 'Mirzapur', 'Moradabad', 'Muzaffarnagar', 'Pilibhit', 'Pratapgarh', 'Prayagraj', 'Raebareli', 'Rampur', 'Saharanpur', 'Sambhal', 'Sant Kabir Nagar', 'Shahjahanpur', 'Shamli', 'Shravasti', 'Siddharthnagar', 'Sitapur', 'Sonbhadra', 'Sultanpur', 'Unnao', 'Varanasi'),
  },
  {
    id: 'uttarakhand',
    name: 'Uttarakhand',
    ut: false,
    districts: _d('Almora', 'Bageshwar', 'Chamoli', 'Champawat', 'Dehradun', 'Haridwar', 'Nainital', 'Pauri Garhwal', 'Pithoragarh', 'Rudraprayag', 'Tehri Garhwal', 'Udham Singh Nagar', 'Uttarkashi'),
  },
  {
    id: 'west-bengal',
    name: 'West Bengal',
    ut: false,
    districts: _d('Alipurduar', 'Bankura', 'Birbhum', 'Cooch Behar', 'Dakshin Dinajpur', 'Darjeeling', 'Hooghly', 'Howrah', 'Jalpaiguri', 'Jhargram', 'Kalimpong', 'Kolkata', 'Malda', 'Murshidabad', 'Nadia', 'North 24 Parganas', 'Paschim Bardhaman', 'Paschim Medinipur', 'Purba Bardhaman', 'Purba Medinipur', 'Purulia', 'South 24 Parganas', 'Uttar Dinajpur'),
  },
  { id: 'andaman-and-nicobar-islands', name: 'Andaman and Nicobar Islands', ut: true, districts: _d('Nicobar', 'North and Middle Andaman', 'South Andaman') },
  { id: 'chandigarh', name: 'Chandigarh', ut: true, districts: _d('Chandigarh') },
  { id: 'dadra-and-nagar-haveli-and-daman-and-diu', name: 'Dadra and Nagar Haveli and Daman and Diu', ut: true, districts: _d('Dadra and Nagar Haveli', 'Daman', 'Diu') },
  { id: 'delhi', name: 'Delhi', ut: true, districts: _d('Central Delhi', 'East Delhi', 'New Delhi', 'North Delhi', 'North East Delhi', 'North West Delhi', 'Shahdara', 'South Delhi', 'South East Delhi', 'South West Delhi', 'West Delhi') },
  { id: 'jammu-and-kashmir', name: 'Jammu and Kashmir', ut: true, districts: _d('Anantnag', 'Bandipora', 'Baramulla', 'Budgam', 'Doda', 'Ganderbal', 'Jammu', 'Kathua', 'Kishtwar', 'Kulgam', 'Kupwara', 'Poonch', 'Pulwama', 'Rajouri', 'Ramban', 'Reasi', 'Samba', 'Shopian', 'Srinagar', 'Udhampur') },
  { id: 'ladakh', name: 'Ladakh', ut: true, districts: _d('Kargil', 'Leh') },
  { id: 'lakshadweep', name: 'Lakshadweep', ut: true, districts: _d('Agatti', 'Amini', 'Andrott', 'Bitra', 'Chetlat', 'Kadmat', 'Kalpeni', 'Kavaratti', 'Kiltan', 'Minicoy') },
  { id: 'puducherry', name: 'Puducherry', ut: true, districts: _d('Karaikal', 'Mahe', 'Puducherry', 'Yanam') },
];

// ── Unit -> kg conversion (normalisation) ────────────────────────────────────

/** kg per reported unit; null means the unit is not a weight we can convert. */
export function unitConversionFactor(rawUnit: string | null | undefined): number | null {
  const u = (rawUnit ?? '').toLowerCase().replace(/[./]/g, ' ').replace(/\s+/g, ' ').trim();
  if (!u) return null;
  if (u.includes('quintal') || u.includes('qtl') || u.includes('100 kg')) return 100;
  if (u.includes('ton') || u.includes('tonne')) return 1000;
  if (u.includes('kg') || u.includes('kilogram')) {
    // "per kg/ Rs kg" -> 1 ; "per 50 kg bag" -> 50
    const m = u.match(/(\d+)\s*kg/);
    if (m) return parseFloat(m[1]);
    return 1;
  }
  if (u.includes('gram') && u.includes('murukku') === false) {
    const m = u.match(/(\d+)\s*gram/);
    if (m) return parseFloat(m[1]) / 1000;
    return 0.001;
  }
  return null; // bags, dozens, pieces, bundles, boxes -> not reliably weight-based
}

/** Human label for display (region-agnostic short form). */
export function unitLabel(rawUnit: string | null | undefined): string {
  const u = (rawUnit ?? '').toLowerCase();
  if (u.includes('quintal') || u.includes('qtl')) return 'Quintal';
  if (u.includes('ton') || u.includes('tonne')) return 'Tonne';
  if (u.includes('100')) return '100 kg';
  if (u.includes('kg') || u.includes('kilogram')) {
    const m = u.match(/(\d+)\s*kg/);
    return m ? `${m[1]} kg` : 'kg';
  }
  if (u.includes('gram')) {
    const m = u.match(/(\d+)\s*gram/);
    return m ? `${m[1]} g` : 'g';
  }
  const tokens = (rawUnit ?? '')
    .replace(/[\u20B9₹]/g, '')
    .replace(/rs\.?/gi, '')
    .replace(/[\/.]/g, ' ')
    .split(/\s+/)
    .map((t) => t.trim())
    .filter((t) => t && !['per', 'of', 'the', 'a', 'an'].includes(t.toLowerCase()));
  if (!tokens.length) return 'Unknown';
  return tokens
    .map((t) => t.charAt(0).toUpperCase() + t.slice(1).toLowerCase())
    .join(' ');
}

// ── Reference commodity list (for the All-India commodity picker) ────────────

export const REFERENCE_COMMODITIES: string[] = [
  'Tomato', 'Potato', 'Onion', 'Chilli', 'Brinjal', 'Cabbage', 'Cauliflower',
  'Carrot', 'Beetroot', 'Bottle Gourd', 'Bitter Gourd', 'Ridge Gourd',
  'Banana', 'Mango', 'Papaya', 'Watermelon', 'Pomegranate', 'Grapes', 'Apple',
  'Orange', 'Coconut', 'Groundnut', 'Soybean', 'Mustard', 'Sunflower', 'Sesame',
  'Paddy', 'Wheat', 'Maize', 'Barley', 'Jowar', 'Bajra', 'Ragi',
  'Chickpea', 'Bengal Gram', 'Green Gram', 'Black Gram', 'Red Gram', 'Pigeon Pea',
  'Sugarcane', 'Cotton', 'Turmeric', 'Ginger', 'Garlic', 'Coriander', 'Fenugreek',
  'Black Pepper', 'Cardamom', 'Coffee', 'Tea', 'Rubber', 'Arecanut', 'Cashewnut',
];