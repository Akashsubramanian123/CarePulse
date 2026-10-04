import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../state/triage_controller.dart';

class ModelSetupScreen extends StatelessWidget {
  const ModelSetupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<TriageController>();

    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
              padding: const EdgeInsets.all(24.0),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 48.0,
                ),
                child: IntrinsicHeight(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Spacer(),

                      // CarePulse App Logo Icon
                      Center(
                        child: Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            color: AppColors.tealGlow,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.tealPrimary, width: 2),
                            boxShadow: const [
                              BoxShadow(
                                color: AppColors.tealGlow,
                                blurRadius: 24,
                                spreadRadius: 4,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.medical_services_rounded,
                            size: 52,
                            color: AppColors.tealAccent,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Title & Subtitle
                      const Text(
                        AppConstants.appName,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textPrimary,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        AppConstants.tagLine,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.tealAccent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Main Status Card
                      Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                          side: const BorderSide(color: AppColors.darkSurfaceBorder),
                        ),
                        color: AppColors.darkSurface,
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            children: [
                              const Text(
                                'Downloading Offline Emergency AI Model (~808 MB)',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'Once downloaded, CarePulse runs 100% offline with zero server calls. Perfect for remote areas, blackouts, and airplane mode.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 24),

                              // Progress Bar & Stats
                              if (controller.isDownloading || controller.isLoadingEngine) ...[
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: LinearProgressIndicator(
                                    value: controller.isLoadingEngine
                                        ? null
                                        : controller.downloadProgress,
                                    minHeight: 12,
                                    backgroundColor: AppColors.darkSurfaceBorder,
                                    valueColor: const AlwaysStoppedAnimation<Color>(
                                      AppColors.tealPrimary,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 14),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      controller.isLoadingEngine
                                          ? 'Initializing Llama engine...'
                                          : '${(controller.downloadProgress * 100).toStringAsFixed(1)}%',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.tealAccent,
                                      ),
                                    ),
                                    Text(
                                      '${controller.downloadedMB.toStringAsFixed(1)} MB / ${controller.totalMB.toStringAsFixed(1)} MB',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ],

                              // Error Banner
                              if (controller.hasError && controller.errorMessage != null) ...[
                                Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: AppColors.coralEmergency.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: AppColors.coralEmergency.withValues(alpha: 0.4)),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.error_outline_rounded,
                                          color: AppColors.coralEmergency, size: 20),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          controller.errorMessage!,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: AppColors.coralEmergency,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),
                              ],
                            ],
                          ),
                        ),
                      ),

                      const Spacer(),

                      // Action Buttons
                      if (controller.isDownloadRequired || controller.hasError)
                        SizedBox(
                          height: 56,
                          child: ElevatedButton.icon(
                            onPressed: () => controller.startModelDownload(),
                            icon: const Icon(Icons.download_rounded),
                            label: const Text('Download Emergency AI Model'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.tealPrimary,
                              foregroundColor: Colors.white,
                              minimumSize: const Size.fromHeight(56),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              elevation: 0,
                            ),
                          ),
                        )
                      else if (controller.isDownloading)
                        SizedBox(
                          height: 56,
                          child: OutlinedButton.icon(
                            onPressed: () => controller.cancelDownload(),
                            icon: const Icon(Icons.cancel_outlined, color: AppColors.textSecondary),
                            label: const Text(
                              'Cancel Download',
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: AppColors.darkSurfaceBorder),
                              minimumSize: const Size.fromHeight(56),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                          ),
                        )
                      else if (controller.isLoadingEngine || controller.isChecking)
                        const Center(
                          child: CircularProgressIndicator(color: AppColors.tealAccent),
                        ),

                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
