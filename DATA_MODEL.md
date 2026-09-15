# LifePlan — โครงสร้างข้อมูล (Data Model)

เอกสารนี้กำหนดโครงสร้างข้อมูล (entities, fields, ความสัมพันธ์) สำหรับแอป LifePlan ใช้เป็นแม่แบบสำหรับ Dart model classes ฝั่ง Flutter และสคีมาฐานข้อมูล/บริการหลังบ้านในอนาคต

ทุก entity มี `id` (String, UUID) และ `createdAt` / `updatedAt` (DateTime, UTC) เป็นมาตรฐานร่วม เว้นแต่ระบุไว้เป็นอื่น

---

## 1. User (ผู้ใช้)

ข้อมูลบัญชีผู้ใช้ ใช้ร่วมกันทุกโมดูล

| ฟิลด์ | ชนิด | คำอธิบาย |
|---|---|---|
| id | String | รหัสผู้ใช้ (UUID) |
| name | String | ชื่อ-นามสกุล |
| email | String | อีเมล (unique) |
| photoUrl | String? | รูปโปรไฟล์ |
| authProvider | enum: `email`, `google`, `apple` | ช่องทางที่ใช้สมัคร/เข้าสู่ระบบ |
| createdAt | DateTime | วันที่สมัคร |
| timezone | String | เขตเวลาของผู้ใช้ เช่น `Asia/Bangkok` |
| dailyGoalMinutes | int | เป้าหมายเวลาทำกิจกรรมรวมต่อวัน (นาที) ใช้คำนวณ % ความสำเร็จหน้า Dashboard |

---

## 2. Exercise (ออกกำลังกาย)

### ExercisePlanItem — แผนออกกำลังกายต่อวัน
| ฟิลด์ | ชนิด | คำอธิบาย |
|---|---|---|
| id | String | |
| userId | String | อ้างอิง User |
| title | String | เช่น "วิ่งตอนเช้า" |
| type | enum: `run`, `strength`, `swim`, `cycle`, `hike`, `stretch`, `other` | ประเภทกิจกรรม |
| scheduledDate | DateTime | วันที่วางแผน |
| durationMinutes | int | ระยะเวลาที่วางแผน |
| caloriesEstimate | int? | แคลอรี่โดยประมาณ |
| isDone | bool | ทำสำเร็จหรือยัง |
| completedAt | DateTime? | เวลาที่ทำเสร็จจริง |
| notes | String? | บันทึกเพิ่มเติม |

### ExerciseWeeklyGoal
| ฟิลด์ | ชนิด | คำอธิบาย |
|---|---|---|
| userId | String | |
| weekStart | DateTime | วันจันทร์ของสัปดาห์ |
| targetSessions | int | เป้าหมายจำนวนครั้ง/สัปดาห์ |

---

## 3. Work (งานประจำ)

### WorkTask
| ฟิลด์ | ชนิด | คำอธิบาย |
|---|---|---|
| id | String | |
| userId | String | |
| title | String | ชื่องาน |
| description | String? | รายละเอียด |
| status | enum: `todo`, `inProgress`, `done` | สถานะ |
| priority | enum: `urgent`, `normal`, `low` | ระดับความสำคัญ |
| dueDate | DateTime? | กำหนดส่ง |
| progressPercent | int | 0–100 ใช้กับงานที่ทำต่อเนื่องหลายวัน |
| completedAt | DateTime? | |

---

## 4. CRM (ลูกค้า & ขายประกัน)

### Client (ลูกค้า)
| ฟิลด์ | ชนิด | คำอธิบาย |
|---|---|---|
| id | String | |
| userId | String | เอเจนต์เจ้าของข้อมูล |
| name | String | ชื่อลูกค้า |
| phone | String? | |
| email | String? | |
| policyType | enum: `health`, `life`, `auto`, `other` | ประเภทกรมธรรม์ที่สนใจ/ถืออยู่ |
| stage | enum: `newLead`, `contacted`, `proposalSent`, `followUp`, `closedWon`, `closedLost` | สถานะในกระบวนการขาย |
| premiumAmount | double? | มูลค่าเบี้ยประกัน (บาท) |
| nextActionDate | DateTime? | วันนัดหมาย/ติดตามถัดไป |
| source | enum: `referral`, `coldCall`, `event`, `online`, `other` | ที่มาของลูกค้า |
| notes | String? | |

### SalesGoal
| ฟิลด์ | ชนิด | คำอธิบาย |
|---|---|---|
| userId | String | |
| month | String | รูปแบบ `YYYY-MM` |
| targetPremium | double | เป้าหมายเบี้ยประกันรวมของเดือน |

---

## 5. Finance (การเงิน)

### Transaction (รายการรายรับ-รายจ่าย)
| ฟิลด์ | ชนิด | คำอธิบาย |
|---|---|---|
| id | String | |
| userId | String | |
| type | enum: `income`, `expense` | |
| category | enum: `food`, `transport`, `investmentSaving`, `commission`, `salary`, `other` | หมวดหมู่ |
| amount | double | จำนวนเงิน (บาท) |
| date | DateTime | วันที่เกิดรายการ |
| note | String? | |

### SavingGoal
| ฟิลด์ | ชนิด | คำอธิบาย |
|---|---|---|
| userId | String | |
| month | String | `YYYY-MM` |
| targetAmount | double | เป้าหมายเงินออมของเดือน |
| currentAmount | double | ยอดออมสะสมปัจจุบัน (คำนวณจาก Transaction category=investmentSaving หรือเก็บแยกก็ได้) |

---

## 6. Learning (เรียนรู้ & พัฒนาตนเอง)

### SkillTrack (เส้นทางการเรียนรู้)
| ฟิลด์ | ชนิด | คำอธิบาย |
|---|---|---|
| id | String | |
| userId | String | |
| name | String | เช่น "ภาษาอังกฤษ", "สกิลการลงทุน", "คณิตศาสตร์", "พัฒนาสมอง" |
| category | enum: `language`, `investing`, `math`, `brainTraining`, `other` | |
| progressPercent | int | 0–100 |
| currentDay | int | เช่น Day 14 |
| level | String? | เช่น "Intermediate" |

### LearningSession (บันทึกการเรียนแต่ละครั้ง)
| ฟิลด์ | ชนิด | คำอธิบาย |
|---|---|---|
| id | String | |
| userId | String | |
| skillTrackId | String | อ้างอิง SkillTrack |
| date | DateTime | |
| durationMinutes | int | |
| lessonTitle | String? | |

### LearningStreak
| ฟิลด์ | ชนิด | คำอธิบาย |
|---|---|---|
| userId | String | |
| currentStreakDays | int | คำนวณจาก LearningSession ต่อเนื่องรายวัน |
| dailyGoalMinutes | int | เป้าหมายนาที/วัน |

---

## 7. Schedule (ตารางเวลา)

### ScheduleEvent
เหตุการณ์ในตารางเวลา — อาจอ้างอิงกลับไปยัง item ของโมดูลอื่น (เช่น ExercisePlanItem, WorkTask, Client follow-up, LearningSession) เพื่อให้ตารางเวลาเป็น "มุมมองรวม" ของทุกโมดูล

| ฟิลด์ | ชนิด | คำอธิบาย |
|---|---|---|
| id | String | |
| userId | String | |
| title | String | |
| category | enum: `exercise`, `work`, `crm`, `finance`, `learning`, `other` | ใช้กำหนดสีในตารางเวลา |
| startTime | DateTime | |
| durationMinutes | int | |
| linkedEntityId | String? | id ของ record ต้นทางในโมดูลนั้น ๆ (ถ้ามี) |
| location | String? | |
| isDone | bool | |

---

## 8. Progress (ความคืบหน้า & วัดผล)

ข้อมูลในหน้านี้ส่วนใหญ่เป็น **ค่าที่คำนวณ (derived/aggregate)** จากโมดูลอื่น ไม่จำเป็นต้องมีตารางเก็บแยกทั้งหมด แต่แนะนำให้ cache เป็นรายสัปดาห์เพื่อประสิทธิภาพ:

### WeeklyScoreSnapshot (แคชคะแนนรายสัปดาห์)
| ฟิลด์ | ชนิด | คำอธิบาย |
|---|---|---|
| userId | String | |
| weekStart | DateTime | วันจันทร์ของสัปดาห์ |
| overallScore | int | 0–100 คะแนนรวม |
| categoryScores | Map<String,int> | เช่น `{"exercise":60,"work":82,"crm":75,"finance":65,"learning":88}` |

### Achievement (ความสำเร็จ/เหรียญรางวัล)
| ฟิลด์ | ชนิด | คำอธิบาย |
|---|---|---|
| id | String | |
| userId | String | |
| type | enum: `streak`, `goalReached`, `milestone` | |
| title | String | เช่น "ต่อเนื่อง 12 วัน" |
| category | enum เดียวกับ ScheduleEvent.category | |
| earnedAt | DateTime | |

---

## 9. ความสัมพันธ์ระหว่าง Entity (สรุป)

```
User (1) ──< ExercisePlanItem
User (1) ──< WorkTask
User (1) ──< Client
User (1) ──< Transaction
User (1) ──< SkillTrack (1) ──< LearningSession
User (1) ──< ScheduleEvent  (linkedEntityId → รายการในโมดูลอื่น)
User (1) ──< Achievement
User (1) ──1 SavingGoal (ต่อเดือน)
User (1) ──1 SalesGoal (ต่อเดือน)
User (1) ──1 ExerciseWeeklyGoal (ต่อสัปดาห์)
```

## 10. แนวทางฝั่ง Flutter

- แต่ละ entity ด้านบน = 1 Dart class ใน `lib/models/` พร้อม `fromJson` / `toJson`
- ระยะแรก (สเตจ mockup → ใช้งานได้จริงบนเครื่อง) เก็บข้อมูลด้วย local storage (เช่น Hive หรือ sqflite) — ยังไม่ต้องมี backend
- **เป้าหมาย (SavingGoal / SalesGoal / ExerciseWeeklyGoal) ในแอปตอนนี้:** รวมเป็นเอกสารเดียว `GoalSettings` (`lib/models/goal_settings.dart`) ใน Hive box `goal_settings` คีย์ `current` — ฟิลด์ `savingTarget` (double, ค่าเริ่มต้น 50,000), `salesTarget` (double, 250,000), `exerciseWeeklyTarget` (int, 5) ยังไม่แยกตามเดือน/สัปดาห์และยังไม่มี `userId`/`currentAmount` (ยอดออมคำนวณจาก Transaction หมวด `investmentSaving`) ถ้าย้ายไป Firestore ค่อยแยกเป็น 3 entity ตามตารางด้านบน
- โครงสร้างนี้ map ตรงกับ Firestore ได้ทันทีถ้าต้องการ sync ข้ามอุปกรณ์ในอนาคต (แต่ละ collection = entity, `userId` เป็น partition key)
