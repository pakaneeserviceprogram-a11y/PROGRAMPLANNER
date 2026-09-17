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

## 3. Nutrition (ทานอาหาร & โภชนาการ)

### MealEntry — มื้ออาหารหนึ่งรายการ
| ฟิลด์ | ชนิด | คำอธิบาย |
|---|---|---|
| id | String | |
| userId | String | อ้างอิง User |
| title | String | ชื่อเมนู เช่น "ข้าวกล้องอกไก่" |
| type | enum: `breakfast`, `lunch`, `dinner`, `snack` | มื้อ |
| date | DateTime | วันของมื้อนี้ (ตัดเวลาออก เหลือปี-เดือน-วัน) |
| time | String | เวลาที่ทาน รูปแบบ `HH:mm` |
| calories | int | พลังงาน (kcal) |
| proteinGrams | double | โปรตีน (กรัม) |
| carbGrams | double | แป้ง / คาร์โบไฮเดรต (กรัม) |
| fatGrams | double | ไขมัน (กรัม) |
| sugarGrams | double | น้ำตาล (กรัม) |
| vitamins | List<enum: `a`, `b`, `c`, `d`, `e`, `k`> | วิตามินที่ได้รับจากมื้อนี้ |
| workoutTiming | enum: `none`, `preWorkout`, `postWorkout` | ความสัมพันธ์กับเวลาออกกำลังกาย |

### WaterLog — การดื่มน้ำรายวัน
| ฟิลด์ | ชนิด | คำอธิบาย |
|---|---|---|
| id | String | = คีย์วัน `yyyy-MM-dd` (หนึ่งรายการต่อหนึ่งวัน บันทึกซ้ำจะทับของเดิม) |
| userId | String | |
| date | DateTime | วันที่ |
| milliliters | int | ปริมาณสะสมของวันนั้น (มล.) — 1 แก้ว = 250 มล. |

### NutritionGoal — เป้าหมายโภชนาการต่อวัน
| ฟิลด์ | ชนิด | คำอธิบาย |
|---|---|---|
| userId | String | |
| calorieTarget | int | พลังงานต่อวัน (ค่าเริ่มต้น 2,000 kcal) |
| proteinTarget | double | โปรตีน (ค่าเริ่มต้น 60 ก.) |
| carbTarget | double | แป้ง (ค่าเริ่มต้น 250 ก.) |
| fatTarget | double | ไขมัน (ค่าเริ่มต้น 65 ก.) |
| sugarLimit | double | **เพดาน** น้ำตาลที่ไม่ควรเกิน (ค่าเริ่มต้น 25 ก. ตามคำแนะนำ WHO) |
| waterTargetMl | int | น้ำดื่มต่อวัน (ค่าเริ่มต้น 2,000 มล.) |

**คะแนนโภชนาการรายวัน** (`Insights.nutritionScore`) = ค่าเฉลี่ยของ 4 ส่วน: พลังงาน/เป้า, โปรตีน/เป้า, น้ำ/เป้า และคะแนนน้ำตาล (อยู่ในเพดาน = เต็ม, เกินเพดานยิ่งมากยิ่งลดลงตามสัดส่วน `sugarLimit / sugarGrams`) — ยังไม่มีข้อมูลทั้งมื้ออาหารและน้ำของวันนั้น = 0

---

## 3.1 Sleep (คุณภาพการนอน)

### SleepEntry — การนอนหนึ่งคืน
| ฟิลด์ | ชนิด | คำอธิบาย |
|---|---|---|
| id | String | = คีย์ **วันที่ตื่น** `yyyy-MM-dd` (หนึ่งรายการต่อหนึ่งคืน บันทึกซ้ำจะทับของเดิม) |
| userId | String | |
| date | DateTime | วันที่ตื่นนอน (ตัดเวลาออก) |
| bedTime | String | เวลาเข้านอน รูปแบบ `HH:mm` |
| wakeTime | String | เวลาตื่น รูปแบบ `HH:mm` |
| quality | enum: `poor`, `fair`, `good`, `excellent` | คุณภาพที่ผู้ใช้รู้สึกตอนตื่น (น้ำหนัก 0.25 / 0.55 / 0.8 / 1.0) |
| awakenings | int | จำนวนครั้งที่ตื่นกลางดึก |
| factors | List<enum: `caffeine`, `lateMeal`, `screen`, `alcohol`, `stress`, `noise`, `lateExercise`> | ปัจจัยรบกวนของคืนนั้น |
| note | String? | บันทึกเพิ่มเติม |

- `durationMinutes` คำนวณจาก `bedTime → wakeTime` โดย**วนข้ามเที่ยงคืน** (`(wake - bed + 1440) % 1440`) — เข้านอน 23:00 ตื่น 06:30 = 450 นาที
- `nightDate` = วันที่ "เข้านอน" ใช้แสดงผลว่า *คืนวันอังคาร* — เข้านอนตั้งแต่เที่ยงวันขึ้นไปคือคืนของวันก่อนหน้าวันที่ตื่น

### SleepGoal — เป้าหมายการนอน
| ฟิลด์ | ชนิด | คำอธิบาย |
|---|---|---|
| userId | String | |
| sleepTargetMinutes | int | เวลานอนต่อคืน (ค่าเริ่มต้น 480 นาที = 8 ชั่วโมง) |

**คะแนนคุณภาพการนอนรายคืน** (`Insights.scoreOfNight`) = ค่าเฉลี่ยของ 3 ส่วน: ระยะเวลานอน/เป้า (ไม่เกิน 100%), น้ำหนักคุณภาพที่ผู้ใช้ให้ และคะแนนการตื่นกลางดึก (ตื่น 1 ครั้ง −15% แต่ไม่ต่ำกว่า 40%) — คืนที่ยังไม่บันทึก = 0

**สรุป 7 คืน** (`SleepStats`) = เวลานอนเฉลี่ย, คุณภาพเฉลี่ย, จำนวนครั้งที่ตื่นกลางดึกเฉลี่ย, **ความสม่ำเสมอของเวลาเข้านอน** (ค่าเฉลี่ยความเบี่ยงเบนของเวลาเข้านอน 0 นาที = 100%, 90 นาทีขึ้นไป = 0% โดยเวลาหลังเที่ยงคืนถูกบวก 24 ชม. ก่อนคำนวณ) และปัจจัยรบกวนที่พบบ่อยที่สุด

---

## 4. Work (งานประจำ)

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

## 5. CRM (ลูกค้า & ขายประกัน)

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

### WeeklyReport (รายงานผลงานประจำสัปดาห์ P-A-S-R-F-N-T)
รายงานที่เอเจนต์ส่งให้หัวหน้าทุกสัปดาห์ — หนึ่งรายการต่อหนึ่งสัปดาห์ (เริ่มวันจันทร์)

| ฟิลด์ | ชนิด | คำอธิบาย |
|---|---|---|
| id | String | = `weekStart` รูปแบบ `yyyy-MM-dd` ของวันจันทร์ ทำให้บันทึกซ้ำทับสัปดาห์เดิมเสมอ |
| weekStart | DateTime | วันจันทร์ของสัปดาห์นั้น |
| ownerName | String | ชื่อที่ขึ้นหัวรายงาน เช่น "ตารางทำงานเอ๋ ประจำสัปดาห์ที่ 29/4/67-5/5/67" |
| activities | Map<ActivityCode, WeeklyActivity> | ตัวเลขของแต่ละตัวย่อ |
| salesPremium | double | เบี้ยประกันโดยประมาณของยอดขาย (S) ในสัปดาห์นั้น (บาท) |

`ActivityCode`: `prospect` (P) • `appointment` (A) • `sales` (S) • `referral` (R) • `followUp` (F) • `newMarket` (N) • `team` (T)

`WeeklyActivity`: `count` (int) + `note` (String — หมายเหตุที่ต่อท้ายบรรทัดในรายงาน เช่น "ลูกค้าใหม่ 3")

### SalesGoal
| ฟิลด์ | ชนิด | คำอธิบาย |
|---|---|---|
| userId | String | |
| month | String | รูปแบบ `YYYY-MM` |
| targetPremium | double | เป้าหมายเบี้ยประกันรวมของเดือน |

---

## 6. Finance (การเงิน)

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

## 7. Learning (เรียนรู้ & พัฒนาตนเอง)

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

## 8. Schedule (ตารางเวลา)

### ScheduleEvent
เหตุการณ์ในตารางเวลา — อาจอ้างอิงกลับไปยัง item ของโมดูลอื่น (เช่น ExercisePlanItem, WorkTask, Client follow-up, LearningSession) เพื่อให้ตารางเวลาเป็น "มุมมองรวม" ของทุกโมดูล

| ฟิลด์ | ชนิด | คำอธิบาย |
|---|---|---|
| id | String | |
| userId | String | |
| title | String | |
| category | enum: `exercise`, `nutrition`, `work`, `crm`, `finance`, `learning`, `other` | ใช้กำหนดสีในตารางเวลา |
| startTime | DateTime | |
| durationMinutes | int | |
| linkedEntityId | String? | id ของ record ต้นทางในโมดูลนั้น ๆ (ถ้ามี) |
| location | String? | |
| isDone | bool | |

> **ที่ implement จริงตอนนี้** (`lib/models/schedule_event.dart`): ใช้ `time` เป็น String `"HH:mm"` แทน `startTime`
> และ `weekday` เป็น int 1–7 (1 = จันทร์ ... 7 = อาทิตย์ ตรงกับ `DateTime.weekday`) เพื่อให้กิจกรรมเป็น
> "ตารางประจำสัปดาห์" ที่วนซ้ำทุกสัปดาห์ ไม่ผูกกับวันที่ใดวันที่หนึ่ง เรคคอร์ดเก่าที่ยังไม่มี `weekday` จะถูกอ่านเป็นวันจันทร์
>
> **`date`** (String? `"yyyy-MM-dd"`, เพิ่ม 2026-09-17) — มีค่า = **นัดหมายเฉพาะวันที่** ขึ้นแค่วันนั้นวันเดียว ไม่วนซ้ำ
> (null = กิจกรรมประจำสัปดาห์แบบเดิม ไฟล์สำรองเก่าจึงอ่านได้เหมือนเดิม `backupFormatVersion` ยังเป็น 1)
> - เก็บเป็นวันล้วนไม่มีเวลา/โซนเวลา กันวันเลื่อน; `weekday` ถูกตั้งให้ตรงกับ `date.weekday` เสมอ (`ScheduleEvent.oneOff`, และ `fromMap` ยึดจาก `date`)
> - ถามว่า "วันนี้มีอะไร" ใช้ `ScheduleEvent.occursOn(day)` / `ScheduleRepository.getForDate(day)` — ส่วน `getByWeekday` / `getWeek` คืน **เฉพาะกิจกรรมประจำสัปดาห์** (ใช้กับการคัดลอกทั้งวัน)
> - นัดเฉพาะวันไม่มีชุด (`seriesOf` คืนตัวเอง), `copyToWeekdays` คืน 0, แจ้งเตือนครั้งเดียว (ไม่ใส่ `matchDateTimeComponents`) และไม่ตั้งถ้าเลยเวลาไปแล้ว
> - แอปเวอร์ชันเก่า (ก่อน 1.5.0) ที่กู้คืนไฟล์สำรองใหม่จะมองนัดเฉพาะวันเป็นกิจกรรมประจำสัปดาห์ของวันนั้น
>
> **`seriesId`** (String?, เพิ่ม 2026-09-16) — กิจกรรมที่คัดลอกไปหลายวันเป็น **รายการแยกวันละ 1 เรคคอร์ด** (id ไม่ซ้ำ แก้ไขทีละวันได้)
> แต่ผูกชุดกันด้วย `seriesId` เพื่อ "แก้ไข/ลบทุกวันในชุด" ได้ ใช้ getter `seriesKey = seriesId ?? id` เสมอ:
> ต้นฉบับ (หรือเรคคอร์ดเก่า) ไม่มี `seriesId` ส่วนสำเนาได้ `seriesId` = id ของต้นฉบับ จึงไม่ต้องแก้ต้นฉบับตอนคัดลอก
> และไฟล์สำรองเก่าอ่านได้เหมือนเดิม (`backupFormatVersion` ยังเป็น 1)
> การคัดลอกข้ามวันที่มีกิจกรรม **ชื่อและเวลาเดียวกัน** อยู่แล้ว (ดู `ScheduleRepository.copyToWeekdays` / `copyDay` / `updateSeries` / `deleteSeries`)

---

## 9. Progress (ความคืบหน้า & วัดผล)

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

## 10. ความสัมพันธ์ระหว่าง Entity (สรุป)

```
User (1) ──< ExercisePlanItem
User (1) ──< MealEntry
User (1) ──< WaterLog (1 รายการต่อวัน, คีย์ = yyyy-MM-dd)
User (1) ──< SleepEntry (1 รายการต่อคืน, คีย์ = yyyy-MM-dd ของวันที่ตื่น)
User (1) ──< WorkTask
User (1) ──< Client
User (1) ──< Transaction
User (1) ──< SkillTrack (1) ──< LearningSession
User (1) ──< ScheduleEvent  (linkedEntityId → รายการในโมดูลอื่น)
User (1) ──< Achievement
User (1) ──1 SavingGoal (ต่อเดือน)
User (1) ──1 SalesGoal (ต่อเดือน)
User (1) ──1 ExerciseWeeklyGoal (ต่อสัปดาห์)
User (1) ──1 NutritionGoal (ต่อวัน)
User (1) ──1 SleepGoal (ต่อคืน)
```

## 11. แนวทางฝั่ง Flutter

- แต่ละ entity ด้านบน = 1 Dart class ใน `lib/models/` พร้อม `fromJson` / `toJson`
- ระยะแรก (สเตจ mockup → ใช้งานได้จริงบนเครื่อง) เก็บข้อมูลด้วย local storage (เช่น Hive หรือ sqflite) — ยังไม่ต้องมี backend
- **เป้าหมาย (SavingGoal / SalesGoal / ExerciseWeeklyGoal / NutritionGoal) ในแอปตอนนี้:** รวมเป็นเอกสารเดียว `GoalSettings` (`lib/models/goal_settings.dart`) ใน Hive box `goal_settings` คีย์ `current` — ฟิลด์ `savingTarget` (double, ค่าเริ่มต้น 50,000), `salesTarget` (double, 250,000), `exerciseWeeklyTarget` (int, 5), `calorieTarget` (int, 2,000), `proteinTarget` (double, 60), `carbTarget` (double, 250), `fatTarget` (double, 65), `sugarLimit` (double, 25), `waterTargetMl` (int, 2,000) ยังไม่แยกตามเดือน/สัปดาห์และยังไม่มี `userId`/`currentAmount` (ยอดออมคำนวณจาก Transaction หมวด `investmentSaving`) ถ้าย้ายไป Firestore ค่อยแยกเป็น 4 entity ตามตารางด้านบน
- โครงสร้างนี้ map ตรงกับ Firestore ได้ทันทีถ้าต้องการ sync ข้ามอุปกรณ์ในอนาคต (แต่ละ collection = entity, `userId` เป็น partition key)
