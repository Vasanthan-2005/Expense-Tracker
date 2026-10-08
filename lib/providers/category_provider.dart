import 'package:flutter/foundation.dart' hide Category;

import '../models/category.dart';
import '../core/database/database_helper.dart';

class CategoryProvider with ChangeNotifier {
  bool _isDisposed = false;
  List<Category> _categories = [];
  Map<int, int> _categorySpentMap = {};
  bool _isLoading = false;

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (!_isDisposed) {
      super.notifyListeners();
    }
  }

  List<Category> get categories => List.unmodifiable(_categories);
  Map<int, int> get categorySpentMap => Map.unmodifiable(_categorySpentMap);
  bool get isLoading => _isLoading;

  int getCategorySpentPaise(int categoryId) {
    return _categorySpentMap[categoryId] ?? 0;
  }

  CategoryProvider() {
    loadCategories();
  }

  Future<void> loadCategories() async {
    _isLoading = true;
    notifyListeners();

    try {
      final db = DatabaseHelper.instance;
      _categories = await db.getCategories();
      final now = DateTime.now();
      _categorySpentMap = await db.getAllCategorySpentPaiseForMonth(now.year, now.month);
    } catch (e) {
      debugPrint('Error loading categories: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshCategorySpent() async {
    try {
      final now = DateTime.now();
      _categorySpentMap = await DatabaseHelper.instance.getAllCategorySpentPaiseForMonth(now.year, now.month);
      notifyListeners();
    } catch (e) {
      debugPrint('Error refreshing category spent: $e');
    }
  }

  Category? getCategoryById(int id) {
    try {
      return _categories.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> addCategory(Category category) async {
    await DatabaseHelper.instance.insertCategory(category);
    await loadCategories();
  }

  Future<void> updateCategory(Category category) async {
    await DatabaseHelper.instance.updateCategory(category);
    await loadCategories();
  }

  Future<void> updateCategoryBudget(int categoryId, int? monthlyBudgetPaise) async {
    await DatabaseHelper.instance.updateCategoryBudget(categoryId, monthlyBudgetPaise);
    await loadCategories();
  }

  Future<void> reorderCategories(int oldIndex, int newIndex) async {
    if (oldIndex == newIndex) return;

    final item = _categories.removeAt(oldIndex);
    _categories.insert(newIndex, item);
    notifyListeners();

    try {
      await DatabaseHelper.instance.updateCategoryOrder(_categories);
    } catch (e) {
      debugPrint('Error updating category order: $e');
      await loadCategories();
    }
  }

  Future<void> deleteCategory(int categoryId, {int? fallbackCategoryId}) async {
    await DatabaseHelper.instance.deleteCategory(categoryId, fallbackCategoryId: fallbackCategoryId);
    await loadCategories();
  }
}
