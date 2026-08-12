import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../constants/colors.dart';
import '../../models/app_state.dart';
import '../../services/api/crop_diagnosis_api.dart';
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
  String? _analyzeError;
  // Raw {matched, best_match, possible_matches} from the backend's real
  // keyword-overlap scoring (see crop_diagnosis_service.match_symptoms) —
  // never a fabricated result the way the old contains()-based logic was.
  Map<String, dynamic>? _matchResult;

  List<dynamic> _referenceList = [];
  bool _isLoadingReference = true;

  @override
  void initState() {
    super.initState();
    _loadReference();
  }

  @override
  void dispose() {
    _symptomController.dispose();
    super.dispose();
  }

  Future<void> _loadReference() async {
    try {
      final list = await CropDiagnosisApi.fetchAll();
      if (!mounted) return;
      setState(() => _referenceList = list);
    } catch (_) {
      // The reference list is a nice-to-have below the diagnosis tool —
      // fail quietly rather than blocking the whole screen on it.
    } finally {
      if (mounted) setState(() => _isLoadingReference = false);
    }
  }

  Future<void> _runDiagnostics(AppState state) async {
    final text = _symptomController.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _isAnalyzing = true;
      _matchResult = null;
      _analyzeError = null;
    });
    try {
      final result = await CropDiagnosisApi.match(text);
      if (!mounted) return;
      setState(() => _matchResult = result);
    } catch (_) {
      if (!mounted) return;
      setState(() => _analyzeError = state.translate('generic_error'));
    } finally {
      if (mounted) setState(() => _isAnalyzing = false);
    }
  }

  /// Khmer text when the app is in Khmer AND the field is actually filled in
  /// (some future reference rows might only ever get English content) —
  /// falls back to English otherwise, never a blank string.
  String _localized(Map<String, dynamic> item, String enKey, String khKey, AppState state) {
    if (state.currentLanguage == 'kh') {
      final kh = item[khKey]?.toString();
      if (kh != null && kh.isNotEmpty) return kh;
    }
    return item[enKey]?.toString() ?? '';
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
                      const Icon(Icons.search_rounded, color: AppColors.primary, size: 24),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          state.translate('ai_agronomist_diagnostics'),
                          style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
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

            if (_analyzeError != null) ...[
              const SizedBox(height: 16),
              Text(
                _analyzeError!,
                style: GoogleFonts.inter(fontSize: 13, color: AppColors.error),
              ),
            ],

            if (_matchResult != null) ...[
              const SizedBox(height: 24),
              _buildMatchResult(state),
            ],

            const SizedBox(height: 24),

            // Reference Section — now the same real, seeded data the
            // matcher itself scores against, instead of a second,
            // separately hardcoded list that could drift out of sync.
            Text(
              state.translate('common_organic_crop_issues'),
              style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (_isLoadingReference)
              const Center(child: CircularProgressIndicator(color: AppColors.primary))
            else
              ..._referenceList.map((d) => _buildDiseaseCard(state, d as Map<String, dynamic>)),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildMatchResult(AppState state) {
    final bool matched = _matchResult!['matched'] == true;

    if (matched) {
      final best = _matchResult!['best_match'] as Map<String, dynamic>;
      final diagnosis = best['diagnosis'] as Map<String, dynamic>;
      final int confidencePct = (((best['confidence'] as num?)?.toDouble() ?? 0) * 100).round();
      final matchedKeywords = (best['matched_keywords'] as List<dynamic>? ?? []).join(', ');

      return CustomCard(
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
                    _localized(diagnosis, 'disease_name', 'disease_name_kh', state),
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              state.translate('keyword_match_confidence', arguments: {'percent': confidencePct.toString()}),
              style: GoogleFonts.inter(fontSize: 11, color: AppColors.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            Text(
              _localized(diagnosis, 'symptoms_description', 'symptoms_description_kh', state),
              style: GoogleFonts.inter(fontSize: 13, color: AppColors.onSurfaceVariant, height: 1.5),
            ),
            const SizedBox(height: 8),
            Text(
              _localized(diagnosis, 'treatment_advice', 'treatment_advice_kh', state),
              style: GoogleFonts.inter(fontSize: 13, color: AppColors.onSurface, height: 1.5, fontWeight: FontWeight.w500),
            ),
            if (matchedKeywords.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                state.translate('matched_keywords_label', arguments: {'keywords': matchedKeywords}),
                style: GoogleFonts.inter(fontSize: 11, color: AppColors.outline, fontStyle: FontStyle.italic),
              ),
            ],
          ],
        ),
      );
    }

    final possibleMatches = (_matchResult!['possible_matches'] as List<dynamic>? ?? []);

    return CustomCard(
      padding: const EdgeInsets.all(20),
      backgroundColor: Colors.amber.withValues(alpha: 0.08),
      borderSide: BorderSide(color: Colors.amber.withValues(alpha: 0.3)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.help_outline_rounded, color: Colors.amber.shade900, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  state.translate('no_confident_match_title'),
                  style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.amber.shade900),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            state.translate('no_confident_match_hint'),
            style: GoogleFonts.inter(fontSize: 13, color: AppColors.onSurfaceVariant, height: 1.4),
          ),
          if (possibleMatches.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              state.translate('possible_matches_label'),
              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.onSurfaceVariant),
            ),
            const SizedBox(height: 6),
            ...possibleMatches.map((m) {
              final match = m as Map<String, dynamic>;
              final diagnosis = match['diagnosis'] as Map<String, dynamic>;
              final int pct = (((match['confidence'] as num?)?.toDouble() ?? 0) * 100).round();
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '• ${_localized(diagnosis, 'disease_name', 'disease_name_kh', state)} ($pct%)',
                  style: GoogleFonts.inter(fontSize: 12, color: AppColors.onSurfaceVariant),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildDiseaseCard(AppState state, Map<String, dynamic> diagnosis) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: CustomCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _localized(diagnosis, 'disease_name', 'disease_name_kh', state),
              style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.onSurface),
            ),
            const SizedBox(height: 6),
            Text(
              state.translate('symptoms_prefix', arguments: {
                'symptoms': _localized(diagnosis, 'symptoms_description', 'symptoms_description_kh', state),
              }),
              style: GoogleFonts.inter(fontSize: 12, color: AppColors.onSurfaceVariant),
            ),
            const SizedBox(height: 4),
            Text(
              state.translate('organic_care_prefix', arguments: {
                'treatment': _localized(diagnosis, 'treatment_advice', 'treatment_advice_kh', state),
              }),
              style: GoogleFonts.inter(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}
