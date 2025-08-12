import { faker } from '@faker-js/faker';
import fs from 'fs';

const genders = ['male', 'female'];
const statuses = ['active', 'deceased'];

function randomDOBWithRange() {
  const start = new Date(1900, 0, 1);
  const end = new Date();
  end.setDate(end.getDate() - 1);
  return faker.date.between({ from: start, to: end });
}

function formatPostgresTimestamp(date) {
  return date.toISOString; //.replace('T', ' ').replace('Z', '');
}

function generatePerson(givenName, familyName, gender, status) {
  const dob = randomDOBWithRange();
  const createdAt = faker.date.recent({ days: 30 });

  return {
    id: faker.string.uuid(),
    given_name: givenName,
    family_name: familyName,
    full_name: `${givenName} ${familyName}`,
    gender,
    dob: dob.toISOString().slice(0, 10),
    place_of_birth: `${faker.location.city()}, ${faker.location.state({ abbreviated: true })}`,
    identifiers: [
      { type: "NATIONAL_ID", value: `2025${faker.string.alphanumeric({ length: 8 }).toUpperCase()}` },
      { type: "crvs", value: faker.string.uuid() }
    ],
    status,
    created_at: formatPostgresTimestamp(createdAt),
    updated_at: formatPostgresTimestamp(createdAt),
    death_date: status === 'deceased' ? formatPostgresTimestamp(faker.date.between({ from: dob, to: new Date() })) : null,
    linked_persons: []
  };
}

function writeBulkFile(filename, people) {
  const lines = [];
  for (const person of people) {
    lines.push(JSON.stringify({ index: { _index: 'test_person_special', _id: person.id } }));
    lines.push(JSON.stringify(person));
  }
  fs.writeFileSync(filename, lines.join('\n') + '\n', 'utf-8');
  console.log(`✅ Generated ${filename}`);
}

function generateHardcodedPeople(list, count = 100) {
  const records = [];
  for (let i = 0; i < count; i++) {
    const [given, family] = faker.helpers.arrayElement(list);
    const gender = faker.helpers.arrayElement(genders);
    const status = faker.helpers.arrayElement(statuses);
    records.push(generatePerson(given, family, gender, status));
  }
  return records;
}

const allPeople = [];

// 1. Accented
const accentedNames = [
  ['José', 'García'], ['François', 'Lévêque'], ['Müller', 'Schröder'], ['Søren', 'Ångström'],
  ['Renée', 'Dubois'], ['Zoë', 'Brontë'], ['Beyoncé', 'Knowles'], ['Niña', 'Pérez'],
  ['André', 'Côté'], ['Maël', 'Durand'], ['Björn', 'Åkesson'], ['João', 'Silva'],
  ['Élodie', 'Lemoine'], ['Álvaro', 'Iglesias'], ['İsmail', 'Yılmaz'], ['Łukasz', 'Kowalski'],
  ['Ñico', 'Martínez'], ['Čedomir', 'Nikolić'], ['Øyvind', 'Hansen'], ['Þór', 'Sigurðsson']
];
allPeople.push(...generateHardcodedPeople(accentedNames));

// 2. Apostrophe/Hyphen
const aposNames = [
  ['Liam', "O’Connor"], ['Ava', "D’Souza"], ['Noah', "Jean-Luc"], ['Emma', "Mary-Anne"],
  ['Jack', "Smith-Jones"], ['Ella', "O'Reilly"], ['Lucas', "Ch’ien"], ['Mia', "T’ang"],
  ['Olivia', "D'Arcy"], ['Ethan', "Mc’Neil"], ['Sophia', "L’Oreal"], ['Jacob', "M’Baku"],
  ['Isla', "N’Dour"], ['Leo', "O’Malley"], ['Chloe', "De’Luca"], ['Oscar', "P’ere"],
  ['Grace', "R’ose"], ['Harry', "St’one"], ['Freya', "D’Urbano"], ['Charlie', "L’Anglais"]
];
allPeople.push(...generateHardcodedPeople(aposNames));

// 3. Arabic
const arabicNames = [
  ['محمد', 'الهاشمي'], ['فاطمة', 'السعودي'], ['سلمان', 'التميمي'], ['زينب', 'العلي'],
  ['عبدالله', 'العمر'], ['خالد', 'القحطاني'], ['علي', 'المهدي'], ['هاجر', 'الشريف'],
  ['ياسر', 'الخطيب'], ['ليلى', 'الدوسري'], ['أحمد', 'البغدادي'], ['جميلة', 'المغربي'],
  ['منصور', 'الأنصاري'], ['هدى', 'الناصر'], ['رامي', 'الزيدي'], ['سارة', 'الفارس'],
  ['نواف', 'الحربي'], ['أمينة', 'الكوفي'], ['عائشة', 'الحسني'], ['بلال', 'المصري']
];
allPeople.push(...generateHardcodedPeople(arabicNames));

// 4. Chinese (given + family)
const chineseNames = [
  ['小明', '王'], ['华', '李'], ['强', '张'], ['丽', '赵'],
  ['芳', '孙'], ['伟', '周'], ['杰', '吴'], ['敏', '郑'],
  ['娜', '冯'], ['军', '陈'], ['磊', '褚'], ['婷', '卫'],
  ['霞', '蒋'], ['艳', '沈'], ['刚', '韩'], ['波', '杨'],
  ['雪', '朱'], ['龙', '秦'], ['平', '尤'], ['浩', '许']
];
allPeople.push(...generateHardcodedPeople(chineseNames));

// 5. Korean
const koreanNames = [
  ['민수', '김'], ['지훈', '박'], ['서연', '이'], ['지민', '최'],
  ['현우', '정'], ['수빈', '조'], ['예준', '윤'], ['하준', '장'],
  ['도윤', '임'], ['예은', '오'], ['시우', '안'], ['지아', '황'],
  ['서윤', '송'], ['하린', '홍'], ['다은', '양'], ['채원', '전'],
  ['윤아', '배'], ['지후', '백'], ['서진', '유'], ['지안', '남']
];
allPeople.push(...generateHardcodedPeople(koreanNames));

// 6. Japanese
const japaneseNames = [
  ['さくら', '高橋'], ['たろう', '佐藤'], ['ゆうこ', '鈴木'], ['しんじ', '山田'],
  ['けんた', '伊藤'], ['はるか', '渡辺'], ['なおき', '中村'], ['みさき', '小林'],
  ['あきら', '加藤'], ['ゆり', '吉田'], ['たかし', '山本'], ['かな', '佐々木'],
  ['ひろし', '松本'], ['えり', '井上'], ['まさし', '木村'], ['あや', '林'],
  ['ゆうた', '清水'], ['まい', '山口'], ['そうた', '斎藤'], ['りな', '石井']
];
allPeople.push(...generateHardcodedPeople(japaneseNames));

// 7. Noisy / Fuzzy
const noisyBase = [
  'Jose', 'Mary', 'John', 'Alex', 'Calvin', 'Helene', 'Anais', 'Grace', 'Freya', 'Oscar',
  'Emily', 'Liam', 'Noah', 'Isla', 'Ethan', 'Chloe', 'Mason', 'Olivia', 'Leo', 'Ava'
];
const noisyVariants = [
  name => name.replace('e', 'é'),
  name => name.replace('a', '@'),
  name => name.replace(/o/i, '0'),
  name => name + faker.helpers.arrayElement(['!', '#', '🔥', '😎']),
  name => name.split('').reverse().join('')
];

for (let i = 0; i < 100; i++) {
  const base = faker.helpers.arrayElement(noisyBase);
  const transform = faker.helpers.arrayElement(noisyVariants);
  const given = transform(base);
  const family = transform(faker.person.lastName());
  const gender = faker.helpers.arrayElement(genders);
  const status = faker.helpers.arrayElement(statuses);
  allPeople.push(generatePerson(given, family, gender, status));
}

writeBulkFile('test_person_special_all.json', allPeople);

