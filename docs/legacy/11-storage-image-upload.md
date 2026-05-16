# 11 — Storage va Image Upload

> Asl §9 mobile parts. Backend tomonidagi qism: `backend/docs/09-storage.md`.

## 1. Bucket'lar (mobile uchun)

| Bucket | Mobile yozadi | Mobile o'qiydi |
|--------|---------------|-----------------|
| `products` | Seller (own products) | Public (catalog) |
| `shops` | Seller (own shop) | Public |
| `avatars` | Owner | Public |
| `verification` | Owner | ❌ private — backend signed URL |
| `payments` | Seller | ❌ private — backend signed URL |
| `categories` | ❌ admin only | Public |
| `banners` | ❌ admin only | Public |

---

## 2. Image picker

```dart
// shared/utils/image_helpers.dart
import 'package:image_picker/image_picker.dart';

Future<XFile?> pickImage({
  ImageSource source = ImageSource.gallery,
  int maxWidth = 2048,
  int imageQuality = 85,
}) async {
  final picker = ImagePicker();
  return await picker.pickImage(
    source: source,
    maxWidth: maxWidth.toDouble(),
    imageQuality: imageQuality,
  );
}

Future<List<XFile>> pickMultipleImages({int maxImages = 10}) async {
  final picker = ImagePicker();
  final files = await picker.pickMultiImage(
    maxWidth: 2048,
    imageQuality: 85,
  );
  return files.take(maxImages).toList();
}
```

> `image_picker` o'zi avtomatik resize qiladi (`maxWidth`, `imageQuality`). Server'ga 2048px JPG yuboriladi.

---

## 3. Manual resize (kerak bo'lsa)

`image_picker`'ning resize ba'zi platformalarda (web) ishlamaydi. `image` paketi bilan manual:

```dart
import 'package:image/image.dart' as img;

Future<Uint8List> resizeImage(Uint8List bytes,
    {int maxWidth = 2048, int quality = 85}) async {
  final image = img.decodeImage(bytes);
  if (image == null) throw 'Invalid image';

  final resized = image.width > maxWidth
      ? img.copyResize(image, width: maxWidth)
      : image;

  return Uint8List.fromList(img.encodeJpg(resized, quality: quality));
}
```

---

## 4. Supabase Storage upload

### 4.1 Public bucket (products)

```dart
Future<String> uploadProductImage(String productId, XFile file) async {
  final bytes = await file.readAsBytes();
  final fileName = '${uuid.v4()}.jpg';
  final path = 'products/$productId/$fileName';

  await Supabase.instance.client.storage
      .from('products')
      .uploadBinary(
        path,
        bytes,
        fileOptions: const FileOptions(
          contentType: 'image/jpeg',
          cacheControl: '3600',
        ),
      );

  // Public URL
  return Supabase.instance.client.storage
      .from('products')
      .getPublicUrl(path);
}
```

### 4.2 Private bucket (verification)

```dart
Future<String> uploadVerificationDoc(String userId, String docType, XFile file) async {
  final bytes = await file.readAsBytes();
  final path = 'verification/$userId/$docType.jpg';

  await Supabase.instance.client.storage
      .from('verification')
      .uploadBinary(
        path,
        bytes,
        fileOptions: const FileOptions(
          contentType: 'image/jpeg',
          upsert: true,  // qayta yuklashda overwrite
        ),
      );

  // Path qaytaradi (URL emas) — backend signed URL bilan ko'radi
  return path;
}
```

### 4.3 Backend so'rovga URL/path yuborish

```dart
// Verification submit
await dio.post('/seller/verification/manual', data: {
  'passport_front_url': passportFrontPath,   // 'verification/.../passport_front.jpg'
  'passport_back_url': passportBackPath,
  'selfie_url': selfiePath,
});
```

> Public bucket uchun **public URL** yuboriladi, private bucket uchun **path** yuboriladi (backend signed URL'ni o'zi generate qiladi).

---

## 5. Mobile signed URL'larni cache qilmaydi

> **Muhim:** Mobile o'z verification status sahifasida o'z hujjatlarini ko'radi. Bu yerda 3-5 ta rasm — caching kerak emas, har sessiyada qaytadan signed URL olish maqbul.
>
> **Lekin mobile app cache'da signed URL'ni saqlamasin** — TTL muammosi (foydalanuvchi 2 soatdan keyin ochsa expired URL).

```dart
class VerificationDocsRepository {
  Future<String> getSignedUrl(String path) async {
    return await Supabase.instance.client.storage
        .from('verification')
        .createSignedUrl(path, 3600);  // 1 hour
  }
  // Cache qilmaymiz — har chaqiriqda yangi URL
}
```

---

## 6. Image rendering — `cached_network_image`

```dart
import 'package:cached_network_image/cached_network_image.dart';

CachedNetworkImage(
  imageUrl: product.images.first.thumbnailUrl,
  placeholder: (_, __) => ShimmerPlaceholder(),
  errorWidget: (_, __, ___) => Icon(Icons.broken_image),
  fit: BoxFit.cover,
)
```

> Public bucket URL'lari uchun cache OK. Signed URL'lar uchun cache **YO'Q** — `cached_network_image` URL bo'yicha cache qiladi, va URL har safar boshqacha bo'lgani uchun cache miss ham bo'lmaydi (lekin disk'da turib qoladi). V1'da disk cleanup cron mobile'da kerak emas.

---

## 7. Upload progress

`Dio` upload uchun (backend orqali) — agar shu yo'l ishlatsangiz:

```dart
await dio.post(
  '/seller/products/$productId/images',
  data: FormData.fromMap({'file': await MultipartFile.fromFile(path)}),
  onSendProgress: (sent, total) {
    setState(() {
      _progress = sent / total;
    });
  },
);
```

Supabase SDK direct upload paytida progress'ni hozircha qo'llab-quvvatlamaydi (V1'da kichik upload — 10 MB limit, progress shart emas).

---

## 8. Validation va error

```dart
Future<void> uploadProductImage(XFile file) async {
  // Format check
  final mime = lookupMimeType(file.path);
  if (mime != 'image/jpeg' && mime != 'image/png' && mime != 'image/webp') {
    throw FormatException(tr('error.invalid_image_format'));
  }

  // Size check
  final size = await file.length();
  if (size > 10 * 1024 * 1024) {
    throw Exception(tr('error.image_too_large'));
  }

  // ... upload
}
```

---

## 9. Image gallery widget (product editor)

```dart
class ProductImageGallery extends StatefulWidget {
  final List<ProductImage> images;
  final void Function(List<ProductImage>) onChanged;

  @override
  State<ProductImageGallery> createState() => _ProductImageGalleryState();
}

class _ProductImageGalleryState extends State<ProductImageGallery> {
  Future<void> _add() async {
    final files = await pickMultipleImages(maxImages: 10 - widget.images.length);
    for (final file in files) {
      // Upload va list'ga qo'shish
    }
  }

  Future<void> _reorder(int oldIndex, int newIndex) async {
    // Reorder API
  }

  Future<void> _remove(int index) async {
    final image = widget.images[index];
    await dio.delete('/seller/products/${productId}/images/${image.id}');
  }

  @override
  Widget build(BuildContext context) {
    return ReorderableListView(
      // ... drag & drop
    );
  }
}
```

---

## 10. Test pattern

```dart
test('uploadProductImage rejects oversized files', () async {
  final file = MockXFile(size: 11 * 1024 * 1024);

  expect(
    () => uploadProductImage(file),
    throwsA(predicate((e) => e.toString().contains('image_too_large'))),
  );
});
```

---

## 11. Keyingi qadam

→ [12-localization.md](./12-localization.md) — multi-language UI
