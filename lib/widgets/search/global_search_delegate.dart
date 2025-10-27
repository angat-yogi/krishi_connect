import 'package:flutter/material.dart';

import '../../models/search_result.dart';
import '../../models/user_model.dart';
import '../../services/search_history_store.dart';
import '../../services/search_service.dart';

const _trendingSearches = <String>[
  'Fresh milk',
  'Organic vegetables',
  'Tomato',
  'Kathmandu sellers',
  'Maize',
  'Potato',
  'Orders pending',
  'Honey',
  'Poultry feed',
  'Seedlings',
];

class GlobalSearchDelegate extends SearchDelegate<SearchResultItem?> {
  GlobalSearchDelegate({
    required this.currentUser,
    required this.searchService,
    required this.historyStore,
  });

  final UserProfile currentUser;
  final SearchService searchService;
  final SearchHistoryStore historyStore;

  @override
  String? get searchFieldLabel => 'Search farmers, sellers, orders…';

  @override
  List<Widget>? buildActions(BuildContext context) {
    if (query.isEmpty) {
      return null;
    }
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () {
          query = '';
          showSuggestions(context);
        },
      ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    if (query.trim().isEmpty) {
      return FutureBuilder<List<String>>(
        future: historyStore.loadHistory(),
        builder: (context, snapshot) {
          final history = snapshot.data ?? const <String>[];
          final items =
              history.isNotEmpty ? history : _trendingSearches.take(10).toList();
          if (items.isEmpty) {
            return const _SuggestionPlaceholder(
              icon: Icons.search,
              message: 'Start typing to search across the marketplace.',
            );
          }
          return ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, index) {
              final term = items[index];
              final isHistory = history.contains(term);
              return ListTile(
                leading: Icon(isHistory ? Icons.history : Icons.trending_up),
                title: Text(term),
                onTap: () {
                  query = term;
                  showResults(context);
                },
                trailing: isHistory
                    ? IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => historyStore.removeTerm(term).then(
                          (_) => showSuggestions(context),
                        ),
                      )
                    : null,
              );
            },
          );
        },
      );
    }

    return FutureBuilder<List<SearchResultItem>>(
      future: searchService.search(
        query,
        currentUser: currentUser,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return const _SuggestionPlaceholder(
            icon: Icons.error_outline,
            message: 'Search failed. Please try again shortly.',
          );
        }
        final results = snapshot.data ?? const <SearchResultItem>[];
        if (results.isEmpty) {
          return const _SuggestionPlaceholder(
            icon: Icons.search_off,
            message: 'No matches found. Try a different keyword.',
          );
        }
        return ListView.builder(
          itemCount: results.length,
          itemBuilder: (context, index) {
            final item = results[index];
            return ListTile(
              leading: Icon(_iconForType(item.type)),
              title: Text(item.title),
              subtitle: Text(item.subtitle),
              onTap: () async {
                await historyStore.addTerm(item.title);
                close(context, item);
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return buildSuggestions(context);
  }
}

class _SuggestionPlaceholder extends StatelessWidget {
  const _SuggestionPlaceholder({
    required this.icon,
    required this.message,
  });

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: Colors.grey[500]),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Colors.grey[600]),
            ),
          ),
        ],
      ),
    );
  }
}

IconData _iconForType(SearchResultType type) {
  switch (type) {
    case SearchResultType.user:
      return Icons.person_outline;
    case SearchResultType.product:
      return Icons.inventory_2_outlined;
    case SearchResultType.order:
      return Icons.receipt_long_outlined;
    case SearchResultType.feedPost:
      return Icons.dynamic_feed_outlined;
  }
}
