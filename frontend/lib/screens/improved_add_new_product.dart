import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../constants/colors.dart';
import '../models/app_state.dart';
import '../widgets/custom_card.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_input.dart';

class ImprovedAddNewProductScreen extends StatefulWidget {
  const ImprovedAddNewProductScreen({super.key});

  @override
  State<ImprovedAddNewProductScreen> createState() => _ImprovedAddNewProductScreenState();
}

class _ImprovedAddNewProductScreenState extends State<ImprovedAddNewProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _qtyController = TextEditingController();
  final _descController = TextEditingController();
  final _locationController = TextEditingController(text: 'Battambang');

  String _selectedCategory = 'Grains';
  String _selectedUnit = 'kg';

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _qtyController.dispose();
    _descController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  void _handleSubmit() {
    if (_formKey.currentState!.validate()) {
      final name = _nameController.text;
      final price = double.tryParse(_priceController.text) ?? 1.0;
      final qty = double.tryParse(_qtyController.text) ?? 100.0;
      final desc = _descController.text;
      final location = _locationController.text;

      final newProduct = MarketProduct(
        id: 'p_${DateTime.now().millisecondsSinceEpoch}',
        name: name,
        category: _selectedCategory,
        price: price,
        unit: _selectedUnit,
        quantity: qty,
        farmerName: 'Chan Sopheap',
        location: location,
        description: desc,
        imageUrl: '',
        isVerifiedFarmer: true,
      );

      Provider.of<AppState>(context, listen: false).addProduct(newProduct);
      Navigator.pop(context);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('"$name" successfully added to the marketplace!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<String> categories = ['Grains', 'Vegetables', 'Fruits'];
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
          'Add New Product',
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
              // Photo Uploader Mock Box
              Text(
                'Product Photo',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Mock Image Picker triggered.')),
                  );
                },
                child: CustomCard(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  backgroundColor: AppColors.surfaceContainerLow,
                  borderSide: const BorderSide(color: AppColors.outlineVariant, style: BorderStyle.solid),
                  child: Center(
                    child: Column(
                      children: [
                        const Icon(
                          Icons.add_photo_alternate_outlined,
                          size: 48,
                          color: AppColors.primary,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Upload Crop Photo',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Supports JPEG, PNG up to 5MB',
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
              const SizedBox(height: 20),

              // Inputs Group
              CustomInput(
                label: 'Crop/Product Name',
                hintText: 'e.g. Organic Brown Rice',
                controller: _nameController,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter crop name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Category Choice Tab
              Text(
                'Category',
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
                        cat,
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
              const SizedBox(height: 16),

              // Pricing Row
              Row(
                children: [
                  Expanded(
                    child: CustomInput(
                      label: 'Price per Unit (\$)',
                      hintText: 'e.g. 1.25',
                      controller: _priceController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (value) {
                        if (value == null || double.tryParse(value) == null) {
                          return 'Enter valid price';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Dropdown unit selector
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Unit Type',
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
                              return DropdownMenuItem(value: u, child: Text('per $u'));
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
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: CustomInput(
                      label: 'Stock Quantity',
                      hintText: 'e.g. 500',
                      controller: _qtyController,
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || double.tryParse(value) == null) {
                          return 'Enter valid stock';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: CustomInput(
                      label: 'Origin Location',
                      hintText: 'e.g. Battambang',
                      controller: _locationController,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Description
              Text(
                'Crop Details & Cultivation Description',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _descController,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Detail farming methods, certificates, fertilizers used, grain quality...',
                  filled: true,
                  fillColor: AppColors.surfaceContainerLow,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppDesign.borderRadiusDefault),
                    borderSide: const BorderSide(color: AppColors.outlineVariant),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Submit Button
              CustomButton(
                text: 'Publish Crop Listing',
                icon: Icons.cloud_upload_outlined,
                onPressed: _handleSubmit,
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
