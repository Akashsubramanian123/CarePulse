import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../state/triage_controller.dart';
import '../widgets/glass_card.dart';

class ModelSetupScreen extends StatelessWidget {
  const ModelSetupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<TriageController>();
    final glass = Theme.of(context).extension<CarePulseGlass>()!;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GradientBackground(
        child: SafeArea(
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
                          child: GlassCard(
                            borderRadius: 50,
                            padding: const EdgeInsets.all(24),
                            tint: glass.accentMint,
                            child: Icon(
                              Icons.medical_services_rounded,
                              size: 52,
                              color: glass.accentMint,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Title & Subtitle
                        Text(
                          AppConstants.appName,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            color: glass.textPrimary,
                            letterSpacing: 1.0,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          AppConstants.tagLine,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: glass.accentMint,
                            fontWeight: FontWeight.w600,
                          ),
                        ),

                        const SizedBox(height: 32),

                        // Main Status Card
                        GlassCard(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            children: [
                              Text(
                                'One-time setup. Download the offline AI model (~808 MB) while you have Wi-Fi. After this, CarePulse works with no internet.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: glass.textPrimary,
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 24),

                              // Progress Bar & Stats
                              if (controller.isDownloading || controller.isLoadingEngine) ...[
                                Container(
                                  height: 12,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.white.withOpacity(0.3)),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: LinearProgressIndicator(
                                      value: controller.isLoadingEngine
                                          ? null
                                          : controller.downloadProgress,
                                      backgroundColor: Colors.transparent,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        glass.accentMint,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 14),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      controller.isLoadingEngine
                                          ? 'Initializing AI engine...'
                                          : '${(controller.downloadProgress * 100).toStringAsFixed(1)}%',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: glass.accentMint,
                                      ),
                                    ),
                                    Text(
                                      '${controller.downloadedMB.toStringAsFixed(1)} MB / ${controller.totalMB.toStringAsFixed(1)} MB',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: glass.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ],

                              // Error Banner
                              if (controller.hasError && controller.errorMessage != null) ...[
                                GlassCard(
                                  padding: const EdgeInsets.all(14),
                                  borderRadius: 16,
                                  tint: const Color(0xFFE05A4F),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.error_outline_rounded,
                                          color: Colors.white, size: 20),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          controller.errorMessage!,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
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

                        const Spacer(),

                        // Action Buttons
                        if (controller.isDownloadRequired || controller.hasError)
                          InkWell(
                            onTap: () => controller.startModelDownload(),
                            borderRadius: BorderRadius.circular(24),
                            child: Container(
                              height: 56,
                              decoration: BoxDecoration(
                                gradient: glass.primaryActionGradient,
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(color: Colors.white.withOpacity(0.4), width: 1),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  Icon(Icons.download_rounded, color: Colors.white),
                                  SizedBox(width: 8),
                                  Text(
                                    'Download Emergency AI Model',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  )
                                ],
                              ),
                            ),
                          )
                        else if (controller.isDownloading)
                          InkWell(
                            onTap: () => controller.cancelDownload(),
                            borderRadius: BorderRadius.circular(24),
                            child: Container(
                              height: 56,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(color: glass.glassBorderColor, width: 1),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.cancel_outlined, color: glass.textPrimary),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Cancel Download',
                                    style: TextStyle(
                                      color: glass.textPrimary,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  )
                                ],
                              ),
                            ),
                          )
                        else if (controller.isLoadingEngine || controller.isChecking)
                          Center(
                            child: CircularProgressIndicator(color: glass.accentMint),
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
      ),
    );
  }
}
