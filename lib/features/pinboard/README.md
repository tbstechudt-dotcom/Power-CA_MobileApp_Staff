# Pinboard Feature

A comprehensive pinboard feature for the PowerCA Mobile app that allows staff to view and interact with announcements, deadlines, and events.

## Features

### 1. **Three Categories**
- **Due Date**: Upcoming deadlines and important dates
- **Meetings**: Scheduled meetings and team gatherings
- **Greetings**: Announcements, celebrations, and wishes

### 2. **Main Pinboard Page**
- Grid view of three category cards
- Visual icons and color coding for each category
- Direct navigation to category-specific lists

### 3. **Category List Pages**
- Filtered list of pinboard items by category
- Card-based layout with:
  - Event title
  - Description preview (truncated)
  - Event date and time
  - Location (if available)
  - Author name
  - Like count and comment count
  - Event image (if available)
- Pull-to-refresh functionality
- Tap to view full details

### 4. **Detail Page with Tabs**

#### **Event Tab**
- Full event details including:
  - Category badge
  - Full title and description
  - Author information with avatar
  - Posted date and time
  - Event date and time
  - Location (if available)
  - Like button with count
  - Event image (full size, if available)

#### **Comments Tab**
- List of all comments
- Add new comment functionality
- Comment information includes:
  - Commenter name and avatar
  - Comment content
  - Posted date and time
  - "Edited" indicator (if comment was updated)
- Empty state when no comments exist

## Architecture

### Clean Architecture Pattern

```
features/pinboard/
├── data/
│   ├── datasources/
│   │   └── pinboard_remote_datasource.dart
│   ├── models/
│   │   ├── pinboard_item_model.dart
│   │   └── comment_model.dart
│   └── repositories/
│       └── pinboard_repository_impl.dart
├── domain/
│   ├── entities/
│   │   ├── pinboard_item.dart
│   │   └── comment.dart
│   ├── repositories/
│   │   └── pinboard_repository.dart
│   └── usecases/
│       ├── get_pinboard_items_usecase.dart
│       ├── get_pinboard_item_by_id_usecase.dart
│       ├── get_comments_usecase.dart
│       ├── add_comment_usecase.dart
│       └── toggle_like_usecase.dart
└── presentation/
    ├── bloc/
    │   ├── pinboard_bloc.dart
    │   ├── pinboard_event.dart
    │   └── pinboard_state.dart
    ├── pages/
    │   ├── pinboard_main_page.dart
    │   ├── pinboard_category_list_page.dart
    │   └── pinboard_detail_page.dart
    └── widgets/
        ├── event_details_tab.dart
        └── comments_tab.dart
```

## Database Setup

### Required Tables

1. **pinboard_items**: Stores event/announcement data
2. **pinboard_comments**: Stores user comments
3. **pinboard_likes**: Stores user likes (many-to-many)

### Setup Instructions

1. Open Supabase Dashboard
2. Navigate to SQL Editor
3. Run the SQL file: `sql/pinboard_schema.sql`
4. Verify tables were created successfully

The schema includes:
- Primary tables with proper relationships
- Indexes for query performance
- Row Level Security (RLS) policies
- Automatic `updated_at` triggers

## Integration Guide

### 1. Add Dependencies

Make sure these packages are in your `pubspec.yaml`:

```yaml
dependencies:
  flutter_bloc: ^8.1.3
  equatable: ^2.0.5
  dartz: ^0.10.1
  supabase_flutter: ^2.0.0
  intl: ^0.18.0
```

### 2. Register Dependencies (Dependency Injection)

If using `get_it` or similar DI, register the pinboard dependencies:

```dart
// Pinboard Data Sources
getIt.registerLazySingleton<PinboardRemoteDataSource>(
  () => PinboardRemoteDataSourceImpl(
    supabaseClient: getIt<SupabaseClient>(),
  ),
);

// Pinboard Repository
getIt.registerLazySingleton<PinboardRepository>(
  () => PinboardRepositoryImpl(
    remoteDataSource: getIt<PinboardRemoteDataSource>(),
    supabaseClient: getIt<SupabaseClient>(),
  ),
);

// Pinboard Use Cases
getIt.registerLazySingleton(() => GetPinboardItemsUseCase(getIt()));
getIt.registerLazySingleton(() => GetPinboardItemByIdUseCase(getIt()));
getIt.registerLazySingleton(() => GetCommentsUseCase(getIt()));
getIt.registerLazySingleton(() => AddCommentUseCase(getIt()));
getIt.registerLazySingleton(() => ToggleLikeUseCase(getIt()));

// Pinboard Bloc
getIt.registerFactory(
  () => PinboardBloc(
    getPinboardItems: getIt(),
    getPinboardItemById: getIt(),
    getComments: getIt(),
    addComment: getIt(),
    toggleLike: getIt(),
  ),
);
```

### 3. Add to Navigation

Add the pinboard main page to your app navigation:

```dart
// Example using go_router
GoRoute(
  path: '/pinboard',
  builder: (context, state) => BlocProvider(
    create: (context) => getIt<PinboardBloc>(),
    child: const PinboardMainPage(),
  ),
),
```

Or add to your drawer/bottom navigation:

```dart
ListTile(
  leading: Icon(Icons.push_pin),
  title: Text('Pinboard'),
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BlocProvider(
          create: (context) => getIt<PinboardBloc>(),
          child: const PinboardMainPage(),
        ),
      ),
    );
  },
),
```

### 4. Provide BLoC

Wrap your pages with `BlocProvider`:

```dart
BlocProvider(
  create: (context) => getIt<PinboardBloc>(),
  child: const PinboardMainPage(),
)
```

## Usage

### Viewing Pinboard Items

1. Navigate to Pinboard from main menu
2. Select a category (Due Date, Meetings, or Greetings)
3. Browse the list of items
4. Tap on any item to view full details

### Interacting with Items

#### Liking an Item
- Tap the heart icon on the event details tab
- Icon turns red when liked
- Like count updates in real-time

#### Adding Comments
1. Navigate to the Comments tab
2. Type your comment in the text field
3. Tap send button or press Enter
4. Comment appears immediately in the list

### Pull to Refresh

Swipe down on any category list to refresh the data.

## API Reference

### Supabase Queries

#### Get All Items (with Category Filter)
```sql
SELECT *,
  pinboard_likes (user_id),
  pinboard_comments (id)
FROM pinboard_items
WHERE category = 'due_date'
ORDER BY created_at DESC
```

#### Get Single Item
```sql
SELECT *,
  pinboard_likes (user_id),
  pinboard_comments (id)
FROM pinboard_items
WHERE id = 'item-uuid'
```

#### Get Comments
```sql
SELECT *
FROM pinboard_comments
WHERE pinboard_item_id = 'item-uuid'
ORDER BY created_at ASC
```

#### Add Comment
```sql
INSERT INTO pinboard_comments
  (pinboard_item_id, author_id, author_name, content)
VALUES ($1, $2, $3, $4)
```

#### Toggle Like
```sql
-- Check if exists
SELECT * FROM pinboard_likes
WHERE pinboard_item_id = $1 AND user_id = $2

-- If exists: DELETE
-- If not exists: INSERT
```

## Customization

### Colors

Each category has a distinct color:
- **Due Date**: Orange (`Colors.orange`)
- **Meetings**: Blue (`Colors.blue`)
- **Greetings**: Green (`Colors.green`)

To change colors, modify the `_getCategoryColor()` method in:
- `pinboard_category_list_page.dart`
- `event_details_tab.dart`

### Date Formats

The app uses these date formats (configurable in respective files):
- **List**: `MMM dd, yyyy` (e.g., "Nov 17, 2025")
- **Detail**: `EEEE, MMMM dd, yyyy` (e.g., "Monday, November 17, 2025")
- **Time**: `hh:mm a` (e.g., "02:30 PM")

## Troubleshooting

### Comments Not Loading
- Check if user is authenticated
- Verify `pinboard_comments` table exists
- Check RLS policies allow read access

### Likes Not Working
- Ensure user is authenticated
- Verify `pinboard_likes` table has unique constraint
- Check RLS policies allow insert/delete

### Images Not Displaying
- Verify image URLs are valid and accessible
- Check Supabase Storage policies if using Supabase Storage
- Ensure network connectivity

### "User not authenticated" Error
- Check if user is logged in
- Verify `auth.users` table contains user record
- Check session token is valid

## Future Enhancements

Potential features to add:
- [ ] Push notifications for new posts
- [ ] Image upload functionality
- [ ] Edit/delete own posts and comments
- [ ] Search and filter functionality
- [ ] Tags and categories
- [ ] User mentions (@username)
- [ ] Rich text formatting
- [ ] Attachments support
- [ ] Share functionality
- [ ] Pinned posts

## Testing

### Unit Tests
```dart
// Test use cases
test('should get pinboard items from repository', () async {
  // Arrange
  when(mockRepository.getPinboardItems(category: any))
      .thenAnswer((_) async => Right(tPinboardItems));

  // Act
  final result = await usecase(category: PinboardCategory.dueDate);

  // Assert
  expect(result, Right(tPinboardItems));
});
```

### Widget Tests
```dart
// Test pinboard page
testWidgets('should display category cards', (tester) async {
  await tester.pumpWidget(MaterialApp(
    home: PinboardMainPage(),
  ));

  expect(find.text('Due Date'), findsOneWidget);
  expect(find.text('Meetings'), findsOneWidget);
  expect(find.text('Greetings'), findsOneWidget);
});
```

## Support

For issues or questions, contact the development team or refer to:
- Main project README
- Supabase documentation
- Flutter BLoC documentation
