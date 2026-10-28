import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/di/app_providers.dart';
import '../../../core/services/csv/product_csv_service.dart';
import '../../../core/themes/app_sizes.dart';
import '../../../domain/entities/product_entity.dart';
import '../../providers/auth/auth_notifier.dart';
import '../../providers/products/products_notifier.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_dialog.dart';
import '../../widgets/app_empty_state.dart';
import '../../widgets/app_loading_more_indicator.dart';
import '../../widgets/app_progress_indicator.dart';
import '../../widgets/app_snack_bar.dart';
import '../../widgets/app_text_field.dart';
import 'components/products_card.dart';

class ProductsScreen extends ConsumerStatefulWidget {
  const ProductsScreen({super.key});

  @override
  ConsumerState<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends ConsumerState<ProductsScreen> {
  final scrollController = ScrollController();
  final searchFieldController = TextEditingController();
  String selectedCategory = 'Semua';

  @override
  void initState() {
    scrollController.addListener(scrollListener);
    searchFieldController.addListener(_onSearchChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(productsNotifierProvider.notifier).getAllProducts();
    });
    super.initState();
  }

  @override
  void dispose() {
    scrollController.removeListener(scrollListener);
    searchFieldController.removeListener(_onSearchChanged);
    scrollController.dispose();
    searchFieldController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {});
  }

  void scrollListener() async {
    final productsState = ref.read(productsNotifierProvider);

    // Automatically load more data on end of scroll position
    if (scrollController.offset == scrollController.position.maxScrollExtent) {
      await ref
          .read(productsNotifierProvider.notifier)
          .getAllProducts(
            offset: productsState.allProducts?.length,
            contains: searchFieldController.text,
          );
    }
  }

  void _handleBackupCsv(BuildContext context) async {
    final products = ref.read(productsNotifierProvider).allProducts ?? [];
    if (products.isEmpty) {
      AppSnackBar.showError('Belum ada produk untuk di-backup');
      return;
    }

    final csvContent = ProductCsvService.instance.exportToCsv(products);
    final filePath = await ProductCsvService.instance.saveCsvToFile(csvContent);

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.file_download_done_rounded, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            const Text('Backup Produk Selesai'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Total ${products.length} produk berhasil di-export ke format CSV.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Lokasi file backup:',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.outline),
              ),
              Container(
                margin: const EdgeInsets.symmetric(vertical: 4),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: SelectableText(
                  filePath,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: csvContent));
                  AppSnackBar.show('Teks CSV berhasil disalin ke clipboard');
                },
                icon: const Icon(Icons.copy_rounded, size: 16),
                label: const Text('Salin Seluruh Teks CSV'),
              ),
              const SizedBox(height: 12),
              Text(
                'Preview Data CSV:',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Container(
                height: 120,
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    csvContent,
                    style: const TextStyle(fontSize: 10, fontFamily: 'monospace'),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  void _handleImportCsv(BuildContext context) {
    final textController = TextEditingController();
    final pathController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Row(
              children: [
                Icon(Icons.upload_file_rounded, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                const Text('Mass Upsert Produk (CSV)'),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Masukkan data CSV atau path file untuk mass upsert (tambah baru & perbarui produk yang sudah ada).',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: pathController,
                            decoration: const InputDecoration(
                              labelText: 'Atau Masukkan Path File .csv',
                              hintText: '/storage/.../products.csv',
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          tooltip: 'Baca File',
                          icon: const Icon(Icons.folder_open_rounded),
                          onPressed: () async {
                            final path = pathController.text.trim();
                            if (path.isEmpty) {
                              AppSnackBar.showError('Masukkan path file terlebih dahulu');
                              return;
                            }
                            final file = File(path);
                            if (file.existsSync()) {
                              final content = await file.readAsString();
                              setDialogState(() {
                                textController.text = content;
                              });
                              AppSnackBar.show('Isi file CSV berhasil dimuat');
                            } else {
                              AppSnackBar.showError('File tidak ditemukan: $path');
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Paste Teks CSV:',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    TextField(
                      controller: textController,
                      maxLines: 7,
                      style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                      decoration: const InputDecoration(
                        hintText: 'id,name,category,price,stock,sold,description,imageUrl\n1,Kopi Susu,Minuman,15000,50,0,Kopi segar,\n2,Roti Bakar,Makanan,20000,30,0,Roti bakar keju,',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '*Format kolom: id, name, category, price, stock, sold, description, imageUrl. Jika produk sudah ada (cocok ID atau Nama), data akan diperbarui. Jika belum ada, produk baru akan dibuat.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 10, color: Theme.of(context).colorScheme.outline),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Batal'),
              ),
              FilledButton.icon(
                onPressed: () async {
                  final csvText = textController.text.trim();
                  if (csvText.isEmpty) {
                    AppSnackBar.showError('Data CSV tidak boleh kosong');
                    return;
                  }

                  Navigator.pop(ctx);

                  final authState = ref.read(authNotifierProvider);
                  if (!authState.isAuthenticated) {
                    AppSnackBar.showError('Unauthenticated');
                    return;
                  }

                  final userId = authState.user!.id;
                  final currentProducts = ref.read(productsNotifierProvider).allProducts ?? [];
                  final repo = ref.read(productRepositoryProvider);

                  try {
                    final stats = await AppDialog.showProgress(() async {
                      return ProductCsvService.instance.upsertProductsFromCsv(
                        csvContent: csvText,
                        currentProducts: currentProducts,
                        repository: repo,
                        userId: userId,
                      );
                    });

                    await ref.read(productsNotifierProvider.notifier).getAllProducts();
                    AppSnackBar.show(
                      'Mass upsert selesai: ${stats.inserted} baru dibuat, ${stats.updated} diperbarui'
                      '${stats.failed > 0 ? ', ${stats.failed} dilewati' : ''}',
                    );
                  } catch (e) {
                    AppSnackBar.showError('Gagal upsert produk: $e');
                  }
                },
                icon: const Icon(Icons.sync_alt_rounded, size: 16),
                label: const Text('Mulai Upsert'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final allProducts = ref.watch(productsNotifierProvider.select((s) => s.allProducts));
    final isLoadingMore = ref.watch(productsNotifierProvider.select((s) => s.isLoadingMore));

    final categories = ['Semua'];
    if (allProducts != null) {
      final cats = allProducts
          .map((p) => p.category.trim().isEmpty ? 'General' : p.category.trim())
          .toSet()
          .toList()
        ..sort();
      categories.addAll(cats);
    }

    final searchQuery = searchFieldController.text.trim().toLowerCase();

    final displayedProducts = allProducts?.where((p) {
      final cat = p.category.trim().isEmpty ? 'General' : p.category.trim();
      final matchesCategory = selectedCategory == 'Semua' || cat.toLowerCase() == selectedCategory.toLowerCase();
      final matchesSearch = searchQuery.isEmpty ||
          p.name.toLowerCase().contains(searchQuery) ||
          cat.toLowerCase().contains(searchQuery) ||
          '${p.id}'.contains(searchQuery);
      return matchesCategory && matchesSearch;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Products'),
        elevation: 0,
        shadowColor: Colors.transparent,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            tooltip: 'Opsi CSV & Backup',
            onSelected: (val) {
              if (val == 'backup') {
                _handleBackupCsv(context);
              } else if (val == 'upsert') {
                _handleImportCsv(context);
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'backup',
                child: Row(
                  children: [
                    Icon(Icons.file_download_outlined, size: 20),
                    SizedBox(width: 8),
                    Text('Backup Produk (CSV)'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'upsert',
                child: Row(
                  children: [
                    Icon(Icons.file_upload_outlined, size: 20),
                    SizedBox(width: 8),
                    Text('Mass Upsert (CSV)'),
                  ],
                ),
              ),
            ],
          ),
          const _AddButton(),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(productsNotifierProvider.notifier).getAllProducts(),
        displacement: 60,
        child: Scrollbar(
          child: CustomScrollView(
            controller: scrollController,
            // Disable scroll when data is null or empty
            physics: (allProducts?.isEmpty ?? true) ? const NeverScrollableScrollPhysics() : null,
            slivers: [
              SliverAppBar(
                floating: true,
                snap: true,
                automaticallyImplyLeading: false,
                collapsedHeight: 70,
                titleSpacing: 0,
                title: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSizes.padding),
                  child: _SearchField(controller: searchFieldController),
                ),
              ),
              if (allProducts != null && allProducts.isNotEmpty)
                SliverToBoxAdapter(
                  child: Container(
                    height: 40,
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: AppSizes.padding),
                      scrollDirection: Axis.horizontal,
                      itemCount: categories.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final cat = categories[index];
                        final isSelected = cat.toLowerCase() == selectedCategory.toLowerCase();

                        return InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () {
                            setState(() {
                              selectedCategory = cat;
                            });
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isSelected
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(context).colorScheme.outlineVariant,
                                width: 1,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                cat,
                                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                  color: isSelected
                                      ? Theme.of(context).colorScheme.onPrimary
                                      : Theme.of(context).colorScheme.onSurface,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              SliverLayoutBuilder(
                builder: (context, _) {
                  if (displayedProducts == null) {
                    return const SliverFillRemaining(
                      hasScrollBody: false,
                      fillOverscroll: true,
                      child: AppProgressIndicator(),
                    );
                  }

                  if (displayedProducts.isEmpty) {
                    return SliverFillRemaining(
                      hasScrollBody: false,
                      fillOverscroll: true,
                      child: AppEmptyState(
                        subtitle: 'No products available, add product to continue',
                        buttonText: 'Add Product',
                        onTapButton: () => context.push('/products/product-create'),
                      ),
                    );
                  }

                  return SliverPadding(
                    padding: const EdgeInsets.fromLTRB(AppSizes.padding, 2, AppSizes.padding, AppSizes.padding),
                    sliver: SliverGrid.builder(
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 200,
                        childAspectRatio: 1 / 1.5,
                        crossAxisSpacing: AppSizes.padding / 2,
                        mainAxisSpacing: AppSizes.padding / 2,
                      ),
                      itemCount: displayedProducts.length,
                      itemBuilder: (context, i) {
                        return _ProductCard(product: displayedProducts[i]);
                      },
                    ),
                  );
                },
              ),
              SliverToBoxAdapter(
                child: AppLoadingMoreIndicator(isLoading: isLoadingMore),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: AppSizes.padding),
      child: AppButton(
        height: 26,
        borderRadius: BorderRadius.circular(4),
        padding: const EdgeInsets.symmetric(horizontal: AppSizes.padding / 2),
        buttonColor: Theme.of(context).colorScheme.surfaceContainer,
        child: Row(
          children: [
            Icon(
              Icons.add,
              size: 12,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: AppSizes.padding / 4),
            Text(
              'Add Product',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
        ),
        onTap: () => context.go('/products/product-create'),
      ),
    );
  }
}

class _SearchField extends ConsumerWidget {
  final TextEditingController controller;

  const _SearchField({required this.controller});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppTextField(
      controller: controller,
      hintText: 'Search Products...',
      type: AppTextFieldType.search,
      textInputAction: TextInputAction.search,
      onChanged: (_) {},
      onEditingComplete: () {
        FocusScope.of(context).unfocus();
        ref.read(productsNotifierProvider.notifier).resetProducts();
        ref.read(productsNotifierProvider.notifier).getAllProducts(contains: controller.text);
      },
      onTapClearButton: () {
        controller.clear();
        ref.read(productsNotifierProvider.notifier).resetProducts();
        ref.read(productsNotifierProvider.notifier).getAllProducts();
      },
    );
  }
}

class _ProductCard extends StatelessWidget {
  final ProductEntity product;

  const _ProductCard({required this.product});

  @override
  Widget build(BuildContext context) {
    return ProductsCard(
      product: product,
      onTap: () => context.go('/products/product-detail/${product.id}'),
    );
  }
}
