/// Default emergency telephone number.
const String defaultEmergencyNumber = '112';

/// Kept as default fallback for backward compatibility.
const String emergencyNumber = defaultEmergencyNumber;

/// Predefined country emergency configuration.
class EmergencyCountry {
  final String name;
  final String number;
  final List<String> countryCodes;

  const EmergencyCountry({
    required this.name,
    required this.number,
    this.countryCodes = const [],
  });
}

/// Supported country list with standard emergency numbers.
const List<EmergencyCountry> emergencyCountries = [
  EmergencyCountry(
    name: 'India',
    number: '112',
    countryCodes: ['IN'],
  ),
  EmergencyCountry(
    name: 'European Union',
    number: '112',
    countryCodes: [
      'AT',
      'BE',
      'BG',
      'HR',
      'CY',
      'CZ',
      'DK',
      'EE',
      'FI',
      'FR',
      'DE',
      'GR',
      'HU',
      'IE',
      'IT',
      'LV',
      'LT',
      'LU',
      'MT',
      'NL',
      'PL',
      'PT',
      'RO',
      'SK',
      'SI',
      'ES',
      'SE'
    ],
  ),
  EmergencyCountry(
    name: 'US / Canada',
    number: '911',
    countryCodes: ['US', 'CA'],
  ),
  EmergencyCountry(
    name: 'United Kingdom',
    number: '999',
    countryCodes: ['GB', 'UK'],
  ),
  EmergencyCountry(
    name: 'Australia',
    number: '000',
    countryCodes: ['AU'],
  ),
  EmergencyCountry(
    name: 'New Zealand',
    number: '111',
    countryCodes: ['NZ'],
  ),
];

/// Identifier for custom user-specified emergency number.
const String customCountryName = 'Other / custom';

/// Resolves the default emergency number based on country code or device locale.
String resolveEmergencyNumberForCountryCode(String? countryCode) {
  if (countryCode == null || countryCode.trim().isEmpty) {
    return defaultEmergencyNumber;
  }
  final code = countryCode.trim().toUpperCase();
  for (final country in emergencyCountries) {
    if (country.countryCodes.contains(code)) {
      return country.number;
    }
  }
  return defaultEmergencyNumber;
}

/// Resolves default country name based on device locale.
String resolveCountryNameForCountryCode(String? countryCode) {
  if (countryCode == null || countryCode.trim().isEmpty) {
    return 'India';
  }
  final code = countryCode.trim().toUpperCase();
  for (final country in emergencyCountries) {
    if (country.countryCodes.contains(code)) {
      return country.name;
    }
  }
  return customCountryName;
}

/// Validates that custom emergency numbers contain digits only and are 2 to 6 digits long.
bool isValidCustomEmergencyNumber(String number) {
  final trimmed = number.trim();
  return RegExp(r'^\d{2,6}$').hasMatch(trimmed);
}
