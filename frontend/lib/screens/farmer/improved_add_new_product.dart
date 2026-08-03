import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../constants/colors.dart';
import '../../models/app_state.dart';
import '../../widgets/custom_card.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_input.dart';
import '../../services/api/upload_api.dart';

class ImprovedAddNewProductScreen extends StatefulWidget {
  final MarketProduct? product;
  const ImprovedAddNewProductScreen({super.key, this.product});

  @override
  State<ImprovedAddNewProductScreen> createState() => _ImprovedAddNewProductScreenState();
}

class _ImprovedAddNewProductScreenState extends State<ImprovedAddNewProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _qtyController = TextEditingController();
  final _descController = TextEditingController();

  String _selectedCategory = 'Grains';
  String _selectedUnit = 'kg';
  String _selectedCurrency = 'USD';
  String? _uploadedImageUrl;
  XFile? _selectedImageFile;
  Uint8List? _selectedImageBytes;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    if (widget.product != null) {
      _nameController.text = widget.product!.name;
      _priceController.text = widget.product!.price.toString();
      _qtyController.text = widget.product!.quantity.toString();
      _descController.text = widget.product!.description;
      _selectedCategory = widget.product!.category;
      _selectedUnit = widget.product!.unit;
      _selectedCurrency = widget.product!.currency;
      _uploadedImageUrl = widget.product!.imageUrl;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _qtyController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    try {
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() {
          _selectedImageFile = image;
          _selectedImageBytes = bytes;
        });
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to pick image: $e')),
      );
    }
  }

  Future<void> _handleSubmit() async {
    if (_formKey.currentState!.validate()) {
      final name = _nameController.text;
      final price = double.tryParse(_priceController.text) ?? 1.0;
      final qty = double.tryParse(_qtyController.text) ?? 100.0;
      final desc = _descController.text;
      final state = Provider.of<AppState>(context, listen: false);
      final location = state.userProfile?['province']?.toString() ?? 'Battambang';

      setState(() {
        _isUploading = true;
      });

      String finalImageUrl = _uploadedImageUrl ?? '';

      if (_selectedImageBytes != null && _selectedImageFile != null) {
        try {
          final token = state.token;
          if (token != null) {
            finalImageUrl = await UploadApi.uploadImage(
              token, 
              _selectedImageBytes!, 
              _selectedImageFile!.name,
            );
          } else {
            // Mock upload simulation if offline
            await Future.delayed(const Duration(seconds: 1));
            finalImageUrl = _selectedImageFile!.name;
          }
        } catch (e) {
          debugPrint('Image upload failed: $e');
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Image upload failed: $e. Saving product.')),
          );
        }
      }

      final updatedProduct = MarketProduct(
        id: widget.product?.id ?? 'p_${DateTime.now().millisecondsSinceEpoch}',
        name: name,
        category: _selectedCategory,
        price: price,
        unit: _selectedUnit,
        currency: _selectedCurrency,
        quantity: qty,
        farmerName: widget.product?.farmerName ?? state.userName,
        location: location,
        description: desc,
        imageUrl: finalImageUrl,
        isVerifiedFarmer: true,
        sellerId: widget.product?.sellerId,
      );

      if (widget.product != null) {
        await state.updateProduct(widget.product!.id, updatedProduct);
      } else {
        await state.addProduct(updatedProduct);
      }

      setState(() {
        _isUploading = false;
      });

      if (!mounted) return;
      Navigator.pop(context);
      
      // Product successfully saved and popped back silently.
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppState>(context);
    final List<String> categories = state.backendCategories
        .map((c) => c['name']?.toString() ?? '')
        .where((n) => n.isNotEmpty)
        .toList();
    if (categories.isNotEmpty && !categories.contains(_selectedCategory)) {
      _selectedCategory = categories.first;
    }
    final List<String> units = ['kg', 'bag', 'ton', 'hand'];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: AppColors.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.product != null
              ? state.translate('edit_product_title')
              : state.translate('add_product_title'),
          style: GoogleFonts.inter(
            color: AppColors.onSurface,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildPhotoUploader(),
              const SizedBox(height: 20),
              _buildNameInput(),
              const SizedBox(height: 16),
              _buildCategoryChips(categories),
              const SizedBox(height: 16),
              _buildPricingRow(units),
              const SizedBox(height: 16),
              _buildCurrencySelection(),
              const SizedBox(height: 16),
              _buildStockField(),
              const SizedBox(height: 16),
              _buildDescriptionField(),
              const SizedBox(height: 32),
              _buildSubmitButton(),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoUploader() {
    final state = Provider.of<AppState>(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          state.translate('product_photo'),
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppColors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _pickImage,
          child: CustomCard(
            padding: _selectedImageBytes != null || (_uploadedImageUrl != null && _uploadedImageUrl!.isNotEmpty)
                ? EdgeInsets.zero
                : const EdgeInsets.symmetric(vertical: 40),
            backgroundColor: AppColors.surfaceContainerLow,
            borderSide: const BorderSide(color: AppColors.outlineVariant, style: BorderStyle.solid),
            child: _selectedImageBytes != null
                ? SizedBox(
                    height: 150,
                    width: double.infinity,
                    child: Stack(
                      children: [
                        Image.memory(
                          _selectedImageBytes!,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                        ),
                        Container(
                          color: Colors.black38,
                          child: const Center(
                            child: Icon(Icons.edit_rounded, color: Colors.white, size: 36),
                          ),
                        ),
                      ],
                    ),
                  )
                : (_uploadedImageUrl != null && _uploadedImageUrl!.isNotEmpty)
                    ? SizedBox(
                        height: 150,
                        width: double.infinity,
                        child: Stack(
                          children: [
                            Image.network(
                              widget.product!.resolvedImageUrl,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: double.infinity,
                            ),
                            Container(
                              color: Colors.black38,
                              child: const Center(
                                child: Icon(Icons.edit_rounded, color: Colors.white, size: 36),
                              ),
                            ),
                          ],
                        ),
                      )
                    : Center(
                        child: Column(
                          children: [
                            const Icon(
                              Icons.add_photo_alternate_outlined,
                              size: 48,
                              color: AppColors.primary,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              state.translate('upload_photo'),
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              state.translate('photo_specs'),
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: AppColors.outline,
                              ),
                            ),
                          ],
                        ),
                      ),
          ),
        ),
      ],
    );
  }

  Widget _buildNameInput() {
    final state = Provider.of<AppState>(context);
    return CustomInput(
      label: state.translate('crop_name'),
      hintText: state.translate('crop_name_hint'),
      controller: _nameController,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return state.translate('enter_crop_name');
        }
        return null;
      },
    );
  }

  Widget _buildCategoryChips(List<String> categories) {
    final state = Provider.of<AppState>(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          state.translate('category'),
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppColors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: categories.map((cat) {
            final isSelected = _selectedCategory == cat;
            return Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: ChoiceChip(
                label: Text(
                  state.translate(cat.toLowerCase()),
                  style: GoogleFonts.inter(
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected ? AppColors.onSecondaryContainer : AppColors.onSurfaceVariant,
                  ),
                ),
                selected: isSelected,
                selectedColor: AppColors.secondaryContainer,
                onSelected: (selected) {
                  if (selected) {
                    setState(() {
                      _selectedCategory = cat;
                    });
                  }
                },
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildPricingRow(List<String> units) {
    final state = Provider.of<AppState>(context);
    return Row(
      children: [
        Expanded(
          child: CustomInput(
            label: state.translate('price_per_unit'),
            hintText: state.translate('price_hint'),
            controller: _priceController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
            ],
            validator: (value) {
              if (value == null || double.tryParse(value) == null) {
                return state.translate('enter_valid_price');
              }
              return null;
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                state.translate('unit_type'),
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(AppDesign.borderRadiusDefault),
                  border: Border.all(color: AppColors.outlineVariant),
                ),
                child: DropdownButton<String>(
                  value: _selectedUnit,
                  isExpanded: true,
                  underline: const SizedBox(),
                  items: units.map((u) {
                    final translateKey = 'unit_$u';
                    return DropdownMenuItem(
                      value: u,
                      child: Text(state.translate(translateKey)),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _selectedUnit = val;
                      });
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCurrencySelection() {
    final state = Provider.of<AppState>(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          state.translate('currency'),
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w900,
            color: AppColors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _buildCurrencyOption('USD', '\$ (USD)'),
            const SizedBox(width: 12),
            _buildCurrencyOption('KHR', '៛ (KHR)'),
          ],
        ),
      ],
    );
  }

  Widget _buildCurrencyOption(String value, String label) {
    final isSelected = _selectedCurrency == value;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedCurrency = value;
          });
        },
        borderRadius: BorderRadius.circular(AppDesign.borderRadiusDefault),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primaryContainer : AppColors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(AppDesign.borderRadiusDefault),
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.outlineVariant,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontWeight: FontWeight.bold,
                color: isSelected ? AppColors.onPrimaryContainer : AppColors.onSurfaceVariant,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStockField() {
    final state = Provider.of<AppState>(context);
    return CustomInput(
      label: state.translate('stock_qty'),
      hintText: state.translate('stock_hint'),
      controller: _qtyController,
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
      ],
      validator: (value) {
        if (value == null || double.tryParse(value) == null) {
          return state.translate('enter_valid_stock');
        }
        return null;
      },
    );
  }

  Widget _buildDescriptionField() {
    final state = Provider.of<AppState>(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          state.translate('crop_details'),
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w900,
            color: AppColors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _descController,
          maxLines: 4,
          decoration: InputDecoration(
            hintText: state.translate('crop_details_hint'),
            filled: true,
            fillColor: AppColors.surfaceContainerLow,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppDesign.borderRadiusDefault),
              borderSide: const BorderSide(color: AppColors.outlineVariant),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    final state = Provider.of<AppState>(context);
    return _isUploading
        ? const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: CircularProgressIndicator(),
            ),
          )
        : CustomButton(
            text: widget.product != null
                ? state.translate('update_listing')
                : state.translate('publish_listing'),
            icon: widget.product != null ? Icons.save_rounded : Icons.cloud_upload_outlined,
            onPressed: _handleSubmit,
          );
  }
}
