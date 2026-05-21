import '../models/multilingual_text.dart';
import '../models/region.dart';

/// Hand-curated subset of Uzbekistan administrative tree. Enough breadth for
/// the address picker UX (region → city → district drill-down) without
/// dragging the full classifier into the bundle. Real backend will return
/// the full tree from `GET /regions`.
class MockRegions {
  const MockRegions._();

  static MultilingualText _ml(String uz, String ru, String en) =>
      MultilingualText(uz: uz, ru: ru, en: en);

  static final List<Region> tree = [
    Region(
      id: 'reg-tashkent-city',
      code: 'TSH',
      name: _ml('Toshkent shahri', 'г. Ташкент', 'Tashkent city'),
      children: [
        Region(
          id: 'reg-tsh-chilanzar',
          code: 'TSH-CHL',
          name: _ml('Chilonzor', 'Чиланзар', 'Chilanzar'),
          parentId: 'reg-tashkent-city',
        ),
        Region(
          id: 'reg-tsh-yashnobod',
          code: 'TSH-YSH',
          name: _ml('Yashnobod', 'Яшнабад', 'Yashnobod'),
          parentId: 'reg-tashkent-city',
        ),
        Region(
          id: 'reg-tsh-mirzo-ulugbek',
          code: 'TSH-MUL',
          name: _ml('Mirzo Ulug\'bek', 'Мирзо Улугбек', 'Mirzo Ulugbek'),
          parentId: 'reg-tashkent-city',
        ),
        Region(
          id: 'reg-tsh-yunusobod',
          code: 'TSH-YUN',
          name: _ml('Yunusobod', 'Юнусабад', 'Yunusobod'),
          parentId: 'reg-tashkent-city',
        ),
        Region(
          id: 'reg-tsh-shaykhantakhur',
          code: 'TSH-SHK',
          name: _ml('Shayxontoxur', 'Шайхантахур', 'Shaykhantakhur'),
          parentId: 'reg-tashkent-city',
        ),
        Region(
          id: 'reg-tsh-uchtepa',
          code: 'TSH-UCH',
          name: _ml('Uchtepa', 'Учтепа', 'Uchtepa'),
          parentId: 'reg-tashkent-city',
        ),
      ],
    ),
    Region(
      id: 'reg-tashkent',
      code: 'TASH',
      name: _ml('Toshkent viloyati', 'Ташкентская обл.', 'Tashkent region'),
      children: [
        Region(
          id: 'reg-tash-angren',
          code: 'TASH-ANG',
          name: _ml('Angren', 'Ангрен', 'Angren'),
          parentId: 'reg-tashkent',
        ),
        Region(
          id: 'reg-tash-chirchiq',
          code: 'TASH-CHR',
          name: _ml('Chirchiq', 'Чирчик', 'Chirchik'),
          parentId: 'reg-tashkent',
        ),
        Region(
          id: 'reg-tash-bekobod',
          code: 'TASH-BEK',
          name: _ml('Bekobod', 'Бекабад', 'Bekabad'),
          parentId: 'reg-tashkent',
        ),
      ],
    ),
    Region(
      id: 'reg-samarkand',
      code: 'SAM',
      name: _ml('Samarqand viloyati', 'Самаркандская обл.', 'Samarkand region'),
      children: [
        Region(
          id: 'reg-sam-samarkand',
          code: 'SAM-SAM',
          name: _ml('Samarqand', 'Самарканд', 'Samarkand'),
          parentId: 'reg-samarkand',
        ),
        Region(
          id: 'reg-sam-kattaqorgon',
          code: 'SAM-KAT',
          name: _ml('Kattaqo\'rg\'on', 'Каттакурган', 'Kattakurgan'),
          parentId: 'reg-samarkand',
        ),
      ],
    ),
    Region(
      id: 'reg-bukhara',
      code: 'BUK',
      name: _ml('Buxoro viloyati', 'Бухарская обл.', 'Bukhara region'),
      children: [
        Region(
          id: 'reg-buk-bukhara',
          code: 'BUK-BUK',
          name: _ml('Buxoro', 'Бухара', 'Bukhara'),
          parentId: 'reg-bukhara',
        ),
        Region(
          id: 'reg-buk-kogon',
          code: 'BUK-KOG',
          name: _ml('Kogon', 'Каган', 'Kogon'),
          parentId: 'reg-bukhara',
        ),
      ],
    ),
    Region(
      id: 'reg-andijan',
      code: 'AND',
      name: _ml('Andijon viloyati', 'Андижанская обл.', 'Andijan region'),
      children: [
        Region(
          id: 'reg-and-andijan',
          code: 'AND-AND',
          name: _ml('Andijon', 'Андижан', 'Andijan'),
          parentId: 'reg-andijan',
        ),
        Region(
          id: 'reg-and-asaka',
          code: 'AND-ASK',
          name: _ml('Asaka', 'Асака', 'Asaka'),
          parentId: 'reg-andijan',
        ),
      ],
    ),
    Region(
      id: 'reg-fergana',
      code: 'FRG',
      name: _ml('Farg\'ona viloyati', 'Ферганская обл.', 'Fergana region'),
      children: [
        Region(
          id: 'reg-frg-fergana',
          code: 'FRG-FRG',
          name: _ml('Farg\'ona', 'Фергана', 'Fergana'),
          parentId: 'reg-fergana',
        ),
        Region(
          id: 'reg-frg-margilan',
          code: 'FRG-MRG',
          name: _ml('Marg\'ilon', 'Маргилан', 'Margilan'),
          parentId: 'reg-fergana',
        ),
        Region(
          id: 'reg-frg-kokand',
          code: 'FRG-KOK',
          name: _ml('Qo\'qon', 'Коканд', 'Kokand'),
          parentId: 'reg-fergana',
        ),
      ],
    ),
    Region(
      id: 'reg-namangan',
      code: 'NAM',
      name: _ml('Namangan viloyati', 'Наманганская обл.', 'Namangan region'),
      children: [
        Region(
          id: 'reg-nam-namangan',
          code: 'NAM-NAM',
          name: _ml('Namangan', 'Наманган', 'Namangan'),
          parentId: 'reg-namangan',
        ),
      ],
    ),
    Region(
      id: 'reg-khorezm',
      code: 'KHO',
      name: _ml('Xorazm viloyati', 'Хорезмская обл.', 'Khorezm region'),
      children: [
        Region(
          id: 'reg-kho-urgench',
          code: 'KHO-URG',
          name: _ml('Urganch', 'Ургенч', 'Urgench'),
          parentId: 'reg-khorezm',
        ),
        Region(
          id: 'reg-kho-khiva',
          code: 'KHO-KHV',
          name: _ml('Xiva', 'Хива', 'Khiva'),
          parentId: 'reg-khorezm',
        ),
      ],
    ),
    Region(
      id: 'reg-kashkadarya',
      code: 'KSH',
      name: _ml('Qashqadaryo viloyati', 'Кашкадарьинская обл.', 'Kashkadarya region'),
      children: [
        Region(
          id: 'reg-ksh-karshi',
          code: 'KSH-KAR',
          name: _ml('Qarshi', 'Карши', 'Karshi'),
          parentId: 'reg-kashkadarya',
        ),
      ],
    ),
    Region(
      id: 'reg-surkhandarya',
      code: 'SUR',
      name: _ml('Surxondaryo viloyati', 'Сурхандарьинская обл.', 'Surkhandarya region'),
      children: [
        Region(
          id: 'reg-sur-termez',
          code: 'SUR-TRM',
          name: _ml('Termiz', 'Термез', 'Termez'),
          parentId: 'reg-surkhandarya',
        ),
      ],
    ),
    Region(
      id: 'reg-jizzakh',
      code: 'JIZ',
      name: _ml('Jizzax viloyati', 'Джизакская обл.', 'Jizzakh region'),
      children: [
        Region(
          id: 'reg-jiz-jizzakh',
          code: 'JIZ-JIZ',
          name: _ml('Jizzax', 'Джизак', 'Jizzakh'),
          parentId: 'reg-jizzakh',
        ),
      ],
    ),
    Region(
      id: 'reg-syrdarya',
      code: 'SYR',
      name: _ml('Sirdaryo viloyati', 'Сырдарьинская обл.', 'Syrdarya region'),
      children: [
        Region(
          id: 'reg-syr-gulistan',
          code: 'SYR-GUL',
          name: _ml('Guliston', 'Гулистан', 'Gulistan'),
          parentId: 'reg-syrdarya',
        ),
      ],
    ),
    Region(
      id: 'reg-navoiy',
      code: 'NAV',
      name: _ml('Navoiy viloyati', 'Навоийская обл.', 'Navoi region'),
      children: [
        Region(
          id: 'reg-nav-navoiy',
          code: 'NAV-NAV',
          name: _ml('Navoiy', 'Навои', 'Navoi'),
          parentId: 'reg-navoiy',
        ),
      ],
    ),
    Region(
      id: 'reg-karakalpakstan',
      code: 'KKS',
      name: _ml('Qoraqalpog\'iston', 'Каракалпакстан', 'Karakalpakstan'),
      children: [
        Region(
          id: 'reg-kks-nukus',
          code: 'KKS-NUK',
          name: _ml('Nukus', 'Нукус', 'Nukus'),
          parentId: 'reg-karakalpakstan',
        ),
      ],
    ),
  ];

  static Region? findById(String id) {
    for (final r in tree) {
      if (r.id == id) return r;
      for (final ch in r.children) {
        if (ch.id == id) return ch;
      }
    }
    return null;
  }
}
