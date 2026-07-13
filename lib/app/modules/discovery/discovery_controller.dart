import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:firebasecrashreport/app/data/models/dance_models.dart';
import 'package:firebasecrashreport/app/data/services/supabase_store.dart';

class DiscoveryController extends GetxController {
  final selectedStyle = "All".obs;
  final searchQuery = "".obs;
  final searchController = TextEditingController();
  final matchingDancers = <DancerProfile>[].obs;
  final isLoadingSearch = false.obs;

  final List<String> styles = [
    "All",
    "Shuffle",
    "Krump",
    "Breaking",
    "Salsa",
    "Popping",
    "Contemporary",
  ];

  @override
  void onInit() {
    super.onInit();
    
    // Perform search reactively when searchQuery changes (debounced by 300ms)
    debounce(searchQuery, (_) => performSearch(), time: const Duration(milliseconds: 300));
  }

  @override
  void onClose() {
    searchController.dispose();
    super.onClose();
  }

  void setStyle(String style) {
    selectedStyle.value = style;
  }

  void updateQuery(String value) {
    searchQuery.value = value;
  }

  void clearQuery() {
    searchController.clear();
    searchQuery.value = "";
    matchingDancers.clear();
  }

  Future<void> performSearch() async {
    final query = searchQuery.value.trim();
    if (query.isEmpty) {
      matchingDancers.clear();
      return;
    }
    isLoadingSearch.value = true;
    try {
      final results = await SupabaseStore.instance.searchUsers(query);
      matchingDancers.value = results;
    } catch (e) {
      debugPrint("Search error in DiscoveryController: $e");
    } finally {
      isLoadingSearch.value = false;
    }
  }
}
