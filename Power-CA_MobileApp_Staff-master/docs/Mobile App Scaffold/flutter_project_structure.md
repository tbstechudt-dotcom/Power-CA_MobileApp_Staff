# PowerCA Flutter Project Structure

```
powerca_mobile/
│
├── lib/
│   ├── main.dart
│   │
│   ├── app/
│   │   ├── app.dart                    # Main app widget
│   │   ├── routes.dart                 # Route definitions
│   │   └── theme.dart                  # App theme configuration
│   │
│   ├── core/
│   │   ├── constants/
│   │   │   ├── api_constants.dart      # API endpoints
│   │   │   ├── app_constants.dart      # App-wide constants
│   │   │   └── storage_constants.dart  # Local storage keys
│   │   │
│   │   ├── config/
│   │   │   ├── app_config.dart         # Environment config
│   │   │   └── injection.dart          # Dependency injection setup
│   │   │
│   │   ├── errors/
│   │   │   ├── exceptions.dart         # Custom exceptions
│   │   │   └── failures.dart           # Failure classes
│   │   │
│   │   ├── network/
│   │   │   ├── api_client.dart         # HTTP client wrapper
│   │   │   ├── network_info.dart       # Network connectivity
│   │   │   └── api_interceptor.dart    # Request/Response interceptors
│   │   │
│   │   └── utils/
│   │       ├── date_utils.dart         # Date formatting utilities
│   │       ├── validators.dart         # Input validators
│   │       ├── file_utils.dart         # File operations
│   │       └── permission_utils.dart   # Permission handling
│   │
│   ├── features/
│   │   │
│   │   ├── auth/
│   │   │   ├── data/
│   │   │   │   ├── models/
│   │   │   │   │   ├── user_model.dart
│   │   │   │   │   └── login_response_model.dart
│   │   │   │   ├── repositories/
│   │   │   │   │   └── auth_repository_impl.dart
│   │   │   │   └── datasources/
│   │   │   │       ├── auth_local_datasource.dart
│   │   │   │       └── auth_remote_datasource.dart
│   │   │   │
│   │   │   ├── domain/
│   │   │   │   ├── entities/
│   │   │   │   │   └── user.dart
│   │   │   │   ├── repositories/
│   │   │   │   │   └── auth_repository.dart
│   │   │   │   └── usecases/
│   │   │   │       ├── login_usecase.dart
│   │   │   │       ├── logout_usecase.dart
│   │   │   │       └── check_auth_status_usecase.dart
│   │   │   │
│   │   │   └── presentation/
│   │   │       ├── bloc/
│   │   │       │   ├── auth_bloc.dart
│   │   │       │   ├── auth_event.dart
│   │   │       │   └── auth_state.dart
│   │   │       ├── pages/
│   │   │       │   ├── splash_page.dart
│   │   │       │   ├── login_page.dart
│   │   │       │   └── forgot_password_page.dart
│   │   │       └── widgets/
│   │   │           ├── login_form.dart
│   │   │           └── password_field.dart
│   │   │
│   │   ├── dashboard/
│   │   │   ├── data/
│   │   │   │   ├── models/
│   │   │   │   │   └── dashboard_stats_model.dart
│   │   │   │   └── repositories/
│   │   │   │       └── dashboard_repository_impl.dart
│   │   │   ├── domain/
│   │   │   │   ├── entities/
│   │   │   │   │   └── dashboard_stats.dart
│   │   │   │   └── repositories/
│   │   │   │       └── dashboard_repository.dart
│   │   │   └── presentation/
│   │   │       ├── bloc/
│   │   │       ├── pages/
│   │   │       │   └── dashboard_page.dart
│   │   │       └── widgets/
│   │   │           ├── stats_card.dart
│   │   │           ├── quick_actions.dart
│   │   │           └── activity_feed.dart
│   │   │
│   │   ├── jobs/
│   │   │   ├── data/
│   │   │   │   ├── models/
│   │   │   │   │   ├── job_model.dart
│   │   │   │   │   ├── task_model.dart
│   │   │   │   │   └── checklist_model.dart
│   │   │   │   ├── repositories/
│   │   │   │   │   └── job_repository_impl.dart
│   │   │   │   └── datasources/
│   │   │   │       └── job_remote_datasource.dart
│   │   │   │
│   │   │   ├── domain/
│   │   │   │   ├── entities/
│   │   │   │   │   ├── job.dart
│   │   │   │   │   ├── task.dart
│   │   │   │   │   └── checklist.dart
│   │   │   │   ├── repositories/
│   │   │   │   │   └── job_repository.dart
│   │   │   │   └── usecases/
│   │   │   │       ├── get_jobs_usecase.dart
│   │   │   │       ├── create_job_usecase.dart
│   │   │   │       ├── update_task_usecase.dart
│   │   │   │       └── complete_checklist_usecase.dart
│   │   │   │
│   │   │   └── presentation/
│   │   │       ├── bloc/
│   │   │       │   ├── job_bloc.dart
│   │   │       │   ├── task_bloc.dart
│   │   │       │   └── checklist_bloc.dart
│   │   │       ├── pages/
│   │   │       │   ├── jobs_list_page.dart
│   │   │       │   ├── job_detail_page.dart
│   │   │       │   ├── create_job_page.dart
│   │   │       │   └── task_checklist_page.dart
│   │   │       └── widgets/
│   │   │           ├── job_card.dart
│   │   │           ├── task_item.dart
│   │   │           └── checklist_item.dart
│   │   │
│   │   ├── work_diary/
│   │   │   ├── data/
│   │   │   │   ├── models/
│   │   │   │   │   └── work_entry_model.dart
│   │   │   │   └── repositories/
│   │   │   │       └── work_diary_repository_impl.dart
│   │   │   ├── domain/
│   │   │   │   ├── entities/
│   │   │   │   │   └── work_entry.dart
│   │   │   │   └── usecases/
│   │   │   │       ├── log_time_usecase.dart
│   │   │   │       └── get_time_entries_usecase.dart
│   │   │   └── presentation/
│   │   │       ├── bloc/
│   │   │       ├── pages/
│   │   │       │   ├── work_diary_page.dart
│   │   │       │   ├── log_time_page.dart
│   │   │       │   └── time_reports_page.dart
│   │   │       └── widgets/
│   │   │           ├── time_entry_card.dart
│   │   │           └── calendar_widget.dart
│   │   │
│   │   ├── clients/
│   │   │   ├── data/
│   │   │   │   ├── models/
│   │   │   │   │   ├── client_model.dart
│   │   │   │   │   └── client_unit_model.dart
│   │   │   │   └── repositories/
│   │   │   │       └── client_repository_impl.dart
│   │   │   ├── domain/
│   │   │   │   ├── entities/
│   │   │   │   │   ├── client.dart
│   │   │   │   │   └── client_unit.dart
│   │   │   │   └── usecases/
│   │   │   │       └── get_clients_usecase.dart
│   │   │   └── presentation/
│   │   │       ├── bloc/
│   │   │       ├── pages/
│   │   │       │   ├── clients_list_page.dart
│   │   │       │   ├── client_detail_page.dart
│   │   │       │   └── add_client_page.dart
│   │   │       └── widgets/
│   │   │           └── client_card.dart
│   │   │
│   │   ├── reminders/
│   │   │   ├── data/
│   │   │   │   ├── models/
│   │   │   │   │   └── reminder_model.dart
│   │   │   │   └── repositories/
│   │   │   │       └── reminder_repository_impl.dart
│   │   │   ├── domain/
│   │   │   │   ├── entities/
│   │   │   │   │   └── reminder.dart
│   │   │   │   └── usecases/
│   │   │   │       └── create_reminder_usecase.dart
│   │   │   └── presentation/
│   │   │       ├── bloc/
│   │   │       ├── pages/
│   │   │       │   ├── reminders_page.dart
│   │   │       │   ├── calendar_page.dart
│   │   │       │   └── create_reminder_page.dart
│   │   │       └── widgets/
│   │   │           ├── reminder_card.dart
│   │   │           └── calendar_event.dart
│   │   │
│   │   ├── staff/
│   │   │   ├── data/
│   │   │   │   ├── models/
│   │   │   │   │   └── staff_model.dart
│   │   │   │   └── repositories/
│   │   │   │       └── staff_repository_impl.dart
│   │   │   ├── domain/
│   │   │   │   ├── entities/
│   │   │   │   │   └── staff.dart
│   │   │   │   └── usecases/
│   │   │   │       └── get_team_usecase.dart
│   │   │   └── presentation/
│   │   │       ├── pages/
│   │   │       │   ├── team_list_page.dart
│   │   │       │   └── staff_profile_page.dart
│   │   │       └── widgets/
│   │   │           └── staff_card.dart
│   │   │
│   │   ├── leave/
│   │   │   ├── data/
│   │   │   ├── domain/
│   │   │   └── presentation/
│   │   │       ├── pages/
│   │   │       │   ├── leave_list_page.dart
│   │   │       │   └── apply_leave_page.dart
│   │   │       └── widgets/
│   │   │
│   │   └── sync/
│   │       ├── data/
│   │       │   ├── models/
│   │       │   │   ├── sync_metadata_model.dart
│   │       │   │   └── sync_log_model.dart
│   │       │   ├── repositories/
│   │       │   │   └── sync_repository_impl.dart
│   │       │   └── datasources/
│   │       │       └── sync_remote_datasource.dart
│   │       │
│   │       ├── domain/
│   │       │   ├── entities/
│   │       │   │   ├── sync_metadata.dart
│   │       │   │   └── sync_log.dart
│   │       │   ├── repositories/
│   │       │   │   └── sync_repository.dart
│   │       │   └── usecases/
│   │       │       ├── get_sync_status_usecase.dart
│   │       │       └── get_sync_logs_usecase.dart
│   │       │
│   │       └── presentation/
│   │           ├── bloc/
│   │           │   ├── sync_bloc.dart
│   │           │   ├── sync_event.dart
│   │           │   └── sync_state.dart
│   │           ├── pages/
│   │           │   ├── sync_dashboard_page.dart
│   │           │   └── sync_logs_page.dart
│   │           └── widgets/
│   │               ├── sync_status_indicator.dart
│   │               ├── sync_health_widget.dart
│   │               ├── data_freshness_indicator.dart
│   │               └── sync_log_item.dart
│   │
│   └── shared/
│       ├── widgets/
│       │   ├── custom_app_bar.dart
│       │   ├── custom_button.dart
│       │   ├── custom_text_field.dart
│       │   ├── loading_indicator.dart
│       │   ├── error_widget.dart
│       │   ├── empty_state.dart
│       │   ├── bottom_nav_bar.dart
│       │   └── sync_status_badge.dart  # Global sync status indicator
│       │
│       └── extensions/
│           ├── context_extensions.dart
│           ├── string_extensions.dart
│           └── date_extensions.dart
│
├── assets/
│   ├── images/
│   │   ├── logo.png
│   │   ├── splash_bg.png
│   │   └── placeholders/
│   ├── icons/
│   └── fonts/
│
├── test/
│   ├── unit/
│   ├── widget/
│   └── integration/
│
├── pubspec.yaml
├── analysis_options.yaml
└── README.md
```

## Architecture: Clean Architecture with BLoC Pattern

### Layers:
1. **Presentation Layer**: UI, Pages, Widgets, BLoC
2. **Domain Layer**: Entities, Use Cases, Repository Interfaces
3. **Data Layer**: Models, Repository Implementations, Data Sources

### Phase 2 Features (Not in current structure):
- **Documents Module**: Camera capture, file upload, PDF/image viewer, document management
  - Will require: `image_picker`, `file_picker`, `flutter_pdfview`, `photo_view` packages
  - Supabase Storage integration for file hosting
  - Additional `features/documents/` module with full Clean Architecture

### Key Dependencies Required:

```yaml
dependencies:
  flutter:
    sdk: flutter
  
  # State Management
  flutter_bloc: ^8.1.3
  equatable: ^2.0.5
  
  # Dependency Injection
  get_it: ^7.6.4
  injectable: ^2.3.2
  
  # Networking
  dio: ^5.3.3
  retrofit: ^4.0.3
  pretty_dio_logger: ^1.3.1
  
  # Local Storage
  shared_preferences: ^2.2.2
  flutter_secure_storage: ^9.0.0
  hive: ^2.2.3
  hive_flutter: ^1.1.0
  
  # Navigation
  go_router: ^12.1.1
  
  # JSON Serialization
  json_annotation: ^4.8.1
  freezed_annotation: ^2.4.1
  
  # UI & Design
  google_fonts: ^6.1.0
  flutter_svg: ^2.0.9
  cached_network_image: ^3.3.0
  shimmer: ^3.0.0
  flutter_screenutil: ^5.9.0
  
  # Date & Time
  intl: ^0.18.1
  timeago: ^3.6.0
  
  # Utilities
  connectivity_plus: ^5.0.2
  permission_handler: ^11.0.1
  url_launcher: ^6.2.1
  path_provider: ^2.1.1
  
  # Charts & Visualization
  fl_chart: ^0.65.0
  
  # Calendar
  table_calendar: ^3.0.9
  
  # Notifications
  flutter_local_notifications: ^16.3.0
  firebase_messaging: ^14.7.4

dev_dependencies:
  flutter_test:
    sdk: flutter
  
  # Code Generation
  build_runner: ^2.4.6
  retrofit_generator: ^8.0.4
  json_serializable: ^6.7.1
  freezed: ^2.4.5
  injectable_generator: ^2.4.1
  hive_generator: ^2.0.1
  
  # Code Quality
  flutter_lints: ^3.0.1
  bloc_test: ^9.1.5
  mockito: ^5.4.3
```
