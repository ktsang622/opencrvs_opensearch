import { faker } from '@faker-js/faker';
import fs from 'fs';

const total = 100000;
const genders = ['male', 'female'];
const statuses = ['active', 'deceased'];

// Date boundaries
const DATE_1950 = new Date(1950, 0, 1);
const DATE_2000 = new Date(2000, 0, 1);
const TODAY = new Date();
TODAY.setDate(TODAY.getDate() - 1);

// Format for PostgreSQL timestamp
function formatTimestamp(date) {
  return date.toISOString().replace('T', ' ').replace('Z', '');
}

// Person record generator
function generatePerson(gender, status, dob) {
  const firstName = faker.person.firstName(gender);
  const lastName = faker.person.lastName();
  const fullName = `${firstName} ${lastName}`;
  const createdAt = faker.date.recent({ days: 60 });
  const updatedAt = createdAt;
  const placeOfBirth = `${faker.location.city()}, ${faker.location.state({ abbreviated: true })}`;

  return {
    id: faker.string.uuid(),
    given_name: firstName,
    family_name: lastName,
    full_name: fullName,
    gender,
    dob: dob.toISOString().slice(0, 10),
    place_of_birth: placeOfBirth,
    identifiers: [
      {
        type: "NATIONAL_ID",
        value: `2025${faker.string.alphanumeric({ length: 8 }).toUpperCase()}`
      },
      {
        type: "crvs",
        value: faker.string.uuid()
      }
    ],
    status,
    created_at: formatTimestamp(createdAt),
    updated_at: formatTimestamp(updatedAt),
    death_date: status === 'deceased' ? formatTimestamp(faker.date.between({ from: dob, to: TODAY })) : null,
    linked_persons: [] // Can extend later
  };
}

// File writers
const bulkPre1950 = [];
const bulk1950_2000 = [];
const bulk2000Onward = [];

for (let i = 0; i < total; i++) {
  const gender = faker.helpers.arrayElement(genders);
  const status = faker.helpers.arrayElement(statuses);

  // Random DOB based on group buckets
  let dob, group;
  const rand = faker.number.float({ min: 0, max: 1 });

  if (rand < 0.1) { // ~10%
    const year = faker.number.int({ min: 1900, max: 1949 });
    dob = new Date(year, 0, 1); // fixed to Jan 1
    group = 'pre1950';
  } else if (rand < 0.65) { // ~55%
    dob = faker.date.between({ from: DATE_1950, to: DATE_2000 });
    group = '1950_2000';
  } else { // ~35%
    dob = faker.date.between({ from: DATE_2000, to: TODAY });
    group = '2000_onward';
  }

  const person = generatePerson(gender, status, dob);
  const indexLine = JSON.stringify({ index: { _index: 'test_person', _id: person.id } });
  const personLine = JSON.stringify(person);

  switch (group) {
    case 'pre1950':
      bulkPre1950.push(indexLine, personLine);
      break;
    case '1950_2000':
      bulk1950_2000.push(indexLine, personLine);
      break;
    case '2000_onward':
      bulk2000Onward.push(indexLine, personLine);
      break;
  }

  if ((i + 1) % 10000 === 0) {
    console.log(`Generated ${i + 1} / ${total}`);
  }
}

// Write all 3 output files
fs.writeFileSync('test_person_bulk_pre1950.json', bulkPre1950.join('\n') + '\n', 'utf-8');
fs.writeFileSync('test_person_bulk_1950_2000.json', bulk1950_2000.join('\n') + '\n', 'utf-8');
fs.writeFileSync('test_person_bulk_2000_onward.json', bulk2000Onward.join('\n') + '\n', 'utf-8');

console.log('✅ Done. All 3 files generated.');

