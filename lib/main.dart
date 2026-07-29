import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/lists_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/lists_screen.dart';

void main() {
  runApp(const GroceryPriceApp());
}

class GroceryPriceApp extends StatelessWidget {
  const GroceryPriceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ListsProvider()..loadLists()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()..loadTheme()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'Grocery Price List',
            themeMode: themeProvider.mode,
            theme: ThemeData(
              colorSchemeSeed: Colors.deepOrange,
              brightness: Brightness.light,
              useMaterial3: true,
            ),
            darkTheme: ThemeData(
              colorSchemeSeed: Colors.deepOrange,
              brightness: Brightness.dark,
              useMaterial3: true,
              scaffoldBackgroundColor: const Color(0xFF121212),
            ),
            home: const ListsScreen(),
          );
        },
      ),
    );
  }
}