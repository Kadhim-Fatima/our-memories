# ذكرياتنا 🤍

موقع Flutter Web خاص للذكريات والصور، يشتغل على **GitHub Pages**، والذكريات والصور تنحفظ على **GitHub** بـ repo خاص.

## شلون يشتغل

| | repo | نوعه | شنو بيه |
|---|---|---|---|
| ١ | `our-memories` | **Public** | كود الموقع فقط (هذا المشروع) |
| ٢ | `our-memories-data` | **Private** | `memories.json` + مجلد `photos/` |

الموقع نفسه ما بيه أي صورة أو ذكرى. أول ما تفتحه يطلب **توكن**، وبيه يقرأ ويرفع على الـ repo الخاص. فحتى لو أحد لگى رابط الموقع، ما يشوف شي بدون التوكن.

---

## خطوات التشغيل (مرة وحدة)

### ١. repo الموقع
1. بـ GitHub سوّي repo جديد اسمه `our-memories` وخليه **Public**.
2. ارفع ملفات هذا المشروع عليه:
   ```bash
   cd our_memories
   git init -b main
   git add .
   git commit -m "first commit"
   git remote add origin https://github.com/USERNAME/our-memories.git
   git push -u origin main
   ```
   > إذا رفعت من موقع GitHub بالسحب والإفلات، تأكد إن مجلد `.github/workflows` انرفع، لأن بعض المتصفحات تتجاهل المجلدات اللي تبدي بنقطة. إذا ما انرفع، سوّي الملف يدوياً: **Actions ← set up a workflow yourself**، سمّه `deploy.yml` والصق محتوى الملف.
3. روح **Settings ← Pages**، وبـ **Source** اختار **GitHub Actions**.
4. روح **Actions** وانتظر لما يخلص (تقريباً ٣ دقايق). الموقع يصير على:
   `https://USERNAME.github.io/our-memories/`

### ٢. repo البيانات (الخاص)
1. سوّي repo جديد اسمه `our-memories-data` وخليه **Private**.
2. فعّل خيار **Add a README file** حتى ينخلق فرع `main`.

### ٣. التوكن
1. GitHub ← صورتك ← **Settings ← Developer settings ← Personal access tokens ← Fine-grained tokens ← Generate new token**.
2. **Repository access**: اختار **Only select repositories** وحدد `our-memories-data` بس.
3. **Permissions ← Repository permissions ← Contents**: اختار **Read and write**.
4. **Expiration**: اختار أطول مدة تريدها.
5. انسخ التوكن (يبدي بـ `github_pat_`).

### ٤. الدخول
افتح الموقع واكتب:
- اسم حساب GitHub مالتك
- اسم الـ repo الخاص: `our-memories-data`
- التوكن

بعدها اضغط ⋯ فوق ← **تعديل الأسماء والتاريخ**.

---

## حتى خطيبتك تفتحه
**الأفضل:** سوّي إلها توكن ثاني بنفس الخطوات (رقم ٣) وانطيه إلها، وهي تدخل بنفس اسم الحساب واسم الـ repo. إذا احتجت توقفه بيوم من الأيام، تحذف توكنها بس وتوكنك يبقى شغال.

**أو:** إذا عندها حساب GitHub، ضيفها **Collaborator** على `our-memories-data` (Settings ← Collaborators)، وهي تسوي توكن من حسابها.

## ملاحظات
- **الصور تتصغر تلقائياً** لحد ٢٠٠٠ بكسل قبل الرفع، حتى الـ repo ما يكبر بسرعة. GitHub ينصح يبقى الـ repo أقل من ١ GB، يعني تقريباً ٢٠٠٠ صورة أو أكثر.
- **التوكن** ينحفظ بالمتصفح فقط. لا تدخل من جهاز مو إلك، وإذا دخلت سجّل خروج من ⋯.
- **كل تعديل يصير commit** بالـ repo الخاص، فعندكم نسخة احتياطية وتاريخ كامل لكل شي.
- إذا تريد تعدّل الكود: عدّل وسوّي `git push`، والموقع يتحدث وحده.

## تشغيله على جهازك
```bash
flutter pub get
flutter run -d chrome
```
