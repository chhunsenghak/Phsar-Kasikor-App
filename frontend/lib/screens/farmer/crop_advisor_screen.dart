import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../constants/colors.dart';
import '../../models/app_state.dart';
import '../../widgets/custom_card.dart';
import '../../widgets/custom_button.dart';

class CropAdvisorScreen extends StatefulWidget {
  const CropAdvisorScreen({super.key});

  @override
  State<CropAdvisorScreen> createState() => _CropAdvisorScreenState();
}

class _CropAdvisorScreenState extends State<CropAdvisorScreen> {
  final TextEditingController _symptomController = TextEditingController();
  bool _isAnalyzing = false;
  Map<String, String>? _diagnosisResult;

  final List<Map<String, String>> _commonDiseases = [
    {
      'name': 'Rice Blast (Magnaporthe oryzae)',
      'symptoms': 'Diamond-shaped spots with gray centers on leaves.',
      'treatment': 'Apply copper-based organic fungicides, reduce nitrogen excess.',
    },
    {
      'name': 'Citrus Canker (Xanthomonas axonopodis)',
      'symptoms': 'Halo-like raised brown lesions on fruits and leaves.',
      'treatment': 'Prune affected branches, apply organic neem sprays.',
    },
    {
      'name': 'Cassava Mosaic Disease (CMD)',
      'symptoms': 'Chlorosis, distorted leaves, and stunted stems.',
      'treatment': 'Use disease-resistant cuttings, control whitefly vector pests.',
    }
  ];

  void _runDiagnostics(AppState state) {
    if (_symptomController.text.trim().isEmpty) return;
    setState(() {
      _isAnalyzing = true;
      _diagnosisResult = null;
    });

    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
          final query = _symptomController.text.toLowerCase();
          if (query.contains('rice') || query.contains('leaf') || query.contains('spot')) {
            _diagnosisResult = {
              'title': 'Suspected Rice Blast Disease (92% match)',
              'details': 'Environmental conditions have favored leaf blast development. Recommended organic treatments: apply certified copper oxide solutions, ensure proper field aeration, and reduce nitrogen-rich fertilizers to prevent host susceptibility.',
            };
          } else if (query.contains('orange') || query.contains('citrus') || query.contains('fruit')) {
            _diagnosisResult = {
              'title': 'Suspected Citrus Canker Infection (87% match)',
              'details': 'Bacteria spread detected. Isolate infected orchards. Apply organic copper sprays during shoots emergence. Prune dead wood after harvests to reduce bacteria levels.',
            };
          } else {
            _diagnosisResult = {
              'title': 'General Soil/Crop Stress Detected (75% match)',
              'details': 'Symptoms point to potential nitrogen deficiency or water logging. Ensure fields are well drained and enrich soil using organic compost or bio-fertilizers.',
            };
          }
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppState>(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          state.translate('crop_diagnostics'),
          style: GoogleFonts.inter(color: AppColors.onSurface, fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Diagnostic input panel
            CustomCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.psychology_outlined, color: AppColors.primary, size: 24),
                      const SizedBox(width: 10),
                      Text(
                        'AI Agronomist Diagnostics',
                        style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _symptomController,
                    maxLines: 3,
                    style: GoogleFonts.inter(fontSize: 14),
                    decoration: InputDecoration(
                      hintText: state.translate('advisor_hint'),
                      hintStyle: GoogleFonts.inter(fontSize: 13, color: AppColors.outline),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.all(12),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_isAnalyzing)
                    const Center(child: CircularProgressIndicator(color: AppColors.primary))
                  else
                    SizedBox(
                      width: double.infinity,
                      child: CustomButton(
                        text: state.translate('diagnose_btn'),
                        backgroundColor: AppColors.primary,
                        onPressed: () => _runDiagnostics(state),
                      ),
                    ),
                ],
              ),
            ),

            if (_diagnosisResult != null) ...[
              const SizedBox(height: 24),
              CustomCard(
                padding: const EdgeInsets.all(20),
                backgroundColor: AppColors.primaryContainer.withValues(alpha: 0.1),
                borderSide: BorderSide(color: AppColors.primary.withValues(alpha: 0.2)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _diagnosisResult!['title']!,
                            style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primary),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _diagnosisResult!['details']!,
                      style: GoogleFonts.inter(fontSize: 13, color: AppColors.onSurfaceVariant, height: 1.5),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Reference Section
            Text(
              'Common Organic Crop Issues',
              style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ..._commonDiseases.map((d) => _buildDiseaseCard(d)),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildDiseaseCard(Map<String, String> disease) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: CustomCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              disease['name']!,
              style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.onSurface),
            ),
            const SizedBox(height: 6),
            Text(
              'Symptoms: ${disease['symptoms']!}',
              style: GoogleFonts.inter(fontSize: 12, color: AppColors.onSurfaceVariant),
            ),
            const SizedBox(height: 4),
            Text(
              'Organic Care: ${disease['treatment']!}',
              style: GoogleFonts.inter(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}
