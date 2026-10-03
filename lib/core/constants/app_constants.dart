class AppConstants {
  static const String appName = 'CarePulse';
  static const String tagLine = 'Offline First-Aid & Quick Response Companion';

  // Model details
  static const String modelUrl =
      'https://huggingface.co/bartowski/Llama-3.2-1B-Instruct-GGUF/resolve/main/Llama-3.2-1B-Instruct-Q4_K_M.gguf';
  static const String modelFileName = 'Llama-3.2-1B-Instruct-Q4_K_M.gguf';
  static const String tempModelFileName = 'Llama-3.2-1B-Instruct-Q4_K_M.gguf.tmp';
  
  // Model size (~808 MB = 847,249,408 bytes, threshold 700 MB)
  static const int minModelSizeBytes = 700 * 1024 * 1024;
  static const double estimatedModelSizeMb = 808.0;

  // Inference Settings
  static const int defaultNCtx = 2048;
  static const int defaultNGpuLayers = 99;

  // Prompts
  static const String systemPrompt =
      'You are CarePulse, an offline first-aid emergency assistant. Respond ONLY with 3 numbered steps under 80 words: 1. IMMEDIATE ACTION, 2. CRITICAL PRECAUTION, 3. MONITOR & STABILIZE. Be calm, concise, direct. No disclaimers.';

  static String formatEmergencyPrompt(String query) {
    return '<|begin_of_text|><|start_header_id|>system<|end_header_id|>\n\n'
        '$systemPrompt<|eot_id|>'
        '<|start_header_id|>user<|end_header_id|>\n\n'
        'EMERGENCY: $query<|eot_id|>'
        '<|start_header_id|>assistant<|end_header_id|>\n\n';
  }
}

class EmergencyPreset {
  final String id;
  final String title;
  final String query;
  final String iconName;

  const EmergencyPreset({
    required this.id,
    required this.title,
    required this.query,
    required this.iconName,
  });
}

const List<EmergencyPreset> emergencyPresets = [
  EmergencyPreset(
    id: 'bleeding',
    title: 'Severe Bleeding',
    query: 'Severe bleeding on limb with spurting blood',
    iconName: 'water_drop',
  ),
  EmergencyPreset(
    id: 'burns',
    title: 'Burn Injury',
    query: 'Second-degree thermal burn on skin from heat or hot liquid',
    iconName: 'local_fire_department',
  ),
  EmergencyPreset(
    id: 'choking',
    title: 'Choking Hazard',
    query: 'Adult choking on object, unable to breathe or cough',
    iconName: 'air',
  ),
  EmergencyPreset(
    id: 'heatstroke',
    title: 'Heatstroke',
    query: 'Person collapsed from extreme heat with high body temperature and confusion',
    iconName: 'wb_sunny',
  ),
  EmergencyPreset(
    id: 'snakebite',
    title: 'Snakebite',
    query: 'Snakebite on foot or hand with swelling and rapid pulse',
    iconName: 'warning_amber',
  ),
];
