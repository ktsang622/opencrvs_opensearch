import { faker } from '@faker-js/faker';
import fs from 'fs';

const genders = ['male', 'female'];
const roles = ['father', 'mother', 'brother', 'sister', 'spouse', 'child', 'friend'];

function randomDate(startYear = 1950, endYear = 2010) {
  const from = new Date(startYear, 0, 1);
  const to = new Date(endYear, 11, 31);
  return faker.date.between({ from, to });
}

function calculateAge(dob) {
  const diffMs = Date.now() - dob.getTime();
  const ageDt = new Date(diffMs);
  return Math.abs(ageDt.getUTCFullYear() - 1970);
}

const total = 100000;
const personsMap = new Map();

// First create base persons without links
for (let i = 1; i <= total; i++) {
  const gender = faker.helpers.arrayElement(genders);
  const firstName = gender === 'male' ? faker.person.firstName('male') : faker.person.firstName('female');
  const lastName = faker.person.lastName();
  const fullName = `${firstName} ${lastName}`;
  const dob = randomDate();
  const age = calculateAge(dob);

  personsMap.set(i.toString(), {
    id: i.toString(),
    full_name: fullName,
    given_name: firstName,
    family_name: lastName,
    gender,
    dob: dob.toISOString().slice(0, 10),
    age,
    linked_persons: []
  });
}

const bulkLines = [];

for (let i = 1; i <= total; i++) {
  const person = personsMap.get(i.toString());

  // Random 0-3 linked persons
  const linkedCount = faker.number.int({ min: 0, max: 3 });
  for (let j = 0; j < linkedCount; j++) {
    let linkedId;
    do {
      linkedId = faker.number.int({ min: 1, max: total }).toString();
    } while (linkedId === i.toString());

    const linkedPerson = personsMap.get(linkedId);
    if (linkedPerson) {
      person.linked_persons.push({
        person_id: linkedId,
        role: faker.helpers.arrayElement(roles),
        full_name: linkedPerson.full_name,
      });
    }
  }

  bulkLines.push(JSON.stringify({ index: { _index: 'test_person', _id: person.id } }));
  bulkLines.push(JSON.stringify(person));
}

fs.writeFileSync('test_person_bulk_100K.json', bulkLines.join('\n') + '\n', 'utf-8');

console.log('Generated test_person_bulk_100K.json');

