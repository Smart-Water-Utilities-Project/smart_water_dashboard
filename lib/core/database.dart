class DatabaseHandler {
  DatabaseHandler._();

  static DatabaseHandler? _instance;
  
  static DatabaseHandler get instance {
    
    return _instance!;
  }
}