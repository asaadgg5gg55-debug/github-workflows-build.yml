#!/bin/bash
set -e
mkdir -p '.'
cat > 'build.gradle.kts' <<'END_OF_FILE_XYZ'
plugins {
    id("com.android.application") version "8.2.0" apply false
    id("org.jetbrains.kotlin.android") version "1.9.20" apply false
}
END_OF_FILE_XYZ
mkdir -p '.'
cat > 'settings.gradle.kts' <<'END_OF_FILE_XYZ'
pluginManagement {
    repositories { google(); mavenCentral(); gradlePluginPortal() }
}
dependencyResolutionManagement {
    repositories { google(); mavenCentral() }
}
rootProject.name = "TvLauncher"
include(":app")
END_OF_FILE_XYZ
mkdir -p '.'
cat > 'gradle.properties' <<'END_OF_FILE_XYZ'
org.gradle.jvmargs=-Xmx2g
android.useAndroidX=false
END_OF_FILE_XYZ
mkdir -p 'app'
cat > 'app/build.gradle.kts' <<'END_OF_FILE_XYZ'
plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
}
android {
    namespace = "com.example.tvlauncher"
    compileSdk = 34
    defaultConfig {
        applicationId = "com.example.tvlauncher"
        minSdk = 21
        targetSdk = 34
        versionCode = 1
        versionName = "1.0"
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions { jvmTarget = "17" }
}
END_OF_FILE_XYZ
mkdir -p 'app/src/main'
cat > 'app/src/main/AndroidManifest.xml' <<'END_OF_FILE_XYZ'
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-feature android:name="android.software.leanback" android:required="false" />
    <uses-feature android:name="android.hardware.touchscreen" android:required="false" />
    <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
    <uses-permission android:name="android.permission.QUERY_ALL_PACKAGES" />

    <application
        android:label="TV Launcher"
        android:supportsRtl="true"
        android:theme="@android:style/Theme.DeviceDefault.NoActionBar">

        <activity
            android:name=".MainActivity"
            android:exported="true"
            android:launchMode="singleTask"
            android:stateNotNeeded="true">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.HOME" />
                <category android:name="android.intent.category.DEFAULT" />
                <category android:name="android.intent.category.LAUNCHER" />
                <category android:name="android.intent.category.LEANBACK_LAUNCHER" />
            </intent-filter>
        </activity>

        <activity android:name=".SetupActivity" android:exported="false" />
    </application>
</manifest>
END_OF_FILE_XYZ
mkdir -p 'app/src/main/java/com/example/tvlauncher'
cat > 'app/src/main/java/com/example/tvlauncher/MainActivity.kt' <<'END_OF_FILE_XYZ'
package com.example.tvlauncher

import android.app.Activity
import android.content.Intent
import android.net.ConnectivityManager
import android.os.Bundle
import android.provider.Settings
import android.text.TextUtils
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.widget.*

class MainActivity : Activity() {
    private var ready = false
    private lateinit var content: LinearLayout
    private lateinit var tabViews: List<TextView>
    private lateinit var wifi: TextView
    private var tab = 0
    private var apps: List<AppItem> = emptyList()
    private val tabNames = listOf("الرئيسية", "التطبيقات", "المفضلة")

    override fun onCreate(b: Bundle?) {
        super.onCreate(b)
        if (!prefs().getBoolean("setup_done", false)) {
            startActivity(Intent(this, SetupActivity::class.java))
            finish()
            return
        }
        ready = true

        val root = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL; setBackgroundColor(BG) }
        val bar = LinearLayout(this).apply {
            gravity = Gravity.CENTER_VERTICAL
            setPadding(dp(48), dp(16), dp(48), dp(8))
        }
        tabViews = tabNames.mapIndexed { i, n ->
            text(n, 18f, GRAY).apply {
                setPadding(dp(20), dp(8), dp(20), dp(8))
                focusCard(0x00000000)
                val prev = onFocusChangeListener
                onFocusChangeListener = View.OnFocusChangeListener { v, f ->
                    prev?.onFocusChange(v, f)
                    if (f && tab != i) { tab = i; render(false) }
                }
                bar.addView(this, LinearLayout.LayoutParams(-2, -2).apply { marginEnd = dp(8) })
            }
        }
        val settingsBtn = text("⚙", 20f).apply {
            setPadding(dp(16), dp(8), dp(16), dp(8))
            focusCard(0x00000000)
            setOnClickListener {
                try { startActivity(Intent(Settings.ACTION_SETTINGS)) } catch (e: Exception) {}
            }
        }
        bar.addView(View(this), LinearLayout.LayoutParams(0, 1, 1f))
        wifi = text("", 20f)
        bar.addView(settingsBtn)
        bar.addView(wifi, LinearLayout.LayoutParams(-2, -2).apply { marginStart = dp(16); marginEnd = dp(16) })
        bar.addView(TextClock(this).apply {
            format12Hour = "h:mm a"; format24Hour = "HH:mm"; textSize = 20f; setTextColor(WHITE)
        })
        root.addView(bar)

        content = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(48), dp(8), dp(48), dp(32))
        }
        root.addView(ScrollView(this).apply {
            isVerticalScrollBarEnabled = false
            clipToPadding = false
            addView(content)
        }, LinearLayout.LayoutParams(-1, 0, 1f))
        setContentView(root)
    }

    override fun onResume() {
        super.onResume()
        if (!ready) return
        apps = loadApps()
        val cm = getSystemService(CONNECTIVITY_SERVICE) as ConnectivityManager
        wifi.text = if (cm.activeNetworkInfo?.isConnected == true) "📶" else "⚠"
        render(true)
    }

    @Deprecated("Deprecated in Java")
    override fun onBackPressed() { /* الرئيسية: لا تخرج */ }

    private fun favSet(): Set<String> = prefs().getStringSet("favs", emptySet()) ?: emptySet()

    private fun render(focus: Boolean) {
        tabViews.forEachIndexed { i, t -> t.setTextColor(if (i == tab) WHITE else GRAY) }
        content.removeAllViews()
        val favs = favSet()
        val favApps = apps.filter { it.pkg in favs }
        when (tab) {
            0 -> {
                content.addView(banner())
                if (favApps.isNotEmpty()) addRow("المفضلة", favApps)
                addRow("التطبيقات", apps)
            }
            1 -> apps.chunked(6).forEachIndexed { i, c -> addRow(if (i == 0) "كل التطبيقات" else "", c) }
            else -> if (favApps.isEmpty())
                content.addView(text("اضغط مطولاً على أي تطبيق لإضافته هنا", 18f, GRAY))
            else favApps.chunked(6).forEachIndexed { i, c -> addRow(if (i == 0) "المفضلة" else "", c) }
        }
        if (focus) content.requestFocus()
    }

    private fun banner(): View {
        val last = prefs().getString("last", null)?.let { p -> apps.firstOrNull { it.pkg == p } }
        val name = prefs().getString("name", "") ?: ""
        return LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(dp(32), dp(24), dp(32), dp(24))
            focusCard(0xFF2B3A67.toInt())
            layoutParams = LinearLayout.LayoutParams(-1, dp(180)).apply { bottomMargin = dp(16) }
            addView(text(if (name.isBlank()) "مرحباً" else "مرحباً، $name", 30f, WHITE, true))
            addView(text(
                if (last != null) "متابعة: " + last.label else "اضغط مطولاً على أي تطبيق لإضافته للمفضلة",
                16f, GRAY))
            setOnClickListener { last?.let { openApp(it.pkg) } }
        }
    }

    private fun addRow(title: String, list: List<AppItem>) {
        if (title.isNotEmpty()) {
            content.addView(text(title, 20f, WHITE, true).apply { setPadding(0, dp(12), 0, 0) })
        }
        val row = LinearLayout(this).apply { orientation = LinearLayout.HORIZONTAL }
        list.forEach { row.addView(tile(it), LinearLayout.LayoutParams(dp(140), -2).apply { marginEnd = dp(12) }) }
        content.addView(HorizontalScrollView(this).apply {
            isHorizontalScrollBarEnabled = false
            clipToPadding = false
            setPadding(dp(8), dp(14), dp(8), dp(14))
            addView(row)
        }, ViewGroup.LayoutParams(-1, -2))
    }

    private fun tile(app: AppItem): View {
        val fav = app.pkg in favSet()
        return LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setPadding(dp(12), dp(16), dp(12), dp(12))
            focusCard()
            addView(ImageView(context).apply { setImageDrawable(app.icon) }, LinearLayout.LayoutParams(dp(72), dp(72)))
            addView(text((if (fav) "★ " else "") + app.label, 14f).apply {
                maxLines = 1; ellipsize = TextUtils.TruncateAt.END; gravity = Gravity.CENTER
                setPadding(0, dp(8), 0, 0)
            })
            setOnClickListener { openApp(app.pkg) }
            setOnLongClickListener {
                val s = favSet().toMutableSet()
                if (!s.add(app.pkg)) s.remove(app.pkg)
                prefs().edit().putStringSet("favs", s).apply()
                Toast.makeText(context, if (app.pkg in s) "أُضيف للمفضلة" else "أُزيل من المفضلة", Toast.LENGTH_SHORT).show()
                render(true)
                true
            }
        }
    }
}
END_OF_FILE_XYZ
mkdir -p 'app/src/main/java/com/example/tvlauncher'
cat > 'app/src/main/java/com/example/tvlauncher/SetupActivity.kt' <<'END_OF_FILE_XYZ'
package com.example.tvlauncher

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import android.provider.Settings
import android.text.InputType
import android.view.Gravity
import android.view.View
import android.widget.*

class SetupActivity : Activity() {
    private lateinit var root: LinearLayout
    private var step = 0
    private val favs = mutableSetOf<String>()
    private var nameField: EditText? = null
    private var emailField: EditText? = null

    override fun onCreate(b: Bundle?) {
        super.onCreate(b)
        root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setBackgroundColor(BG)
            setPadding(dp(80), dp(40), dp(80), dp(40))
        }
        setContentView(root)
        favs.addAll(prefs().getStringSet("favs", emptySet()) ?: emptySet())
        show()
    }

    private fun next() { step++; show() }

    private fun show() {
        root.removeAllViews()
        when (step) {
            0 -> { title("أهلاً بك"); body("لنجهّز جهازك في خطوات بسيطة بالريموت"); btn("ابدأ") { next() }.requestFocus() }
            1 -> {
                title("اللغة"); body("اللغة يحددها النظام. افتح إعداداتها لو تحب تغيّرها")
                btn("فتح إعدادات اللغة") { open(Settings.ACTION_LOCALE_SETTINGS) }
                btn("متابعة") { next() }.requestFocus()
            }
            2 -> {
                title("الشبكة"); body("اتصل بالواي فاي لو لم تكن متصلاً")
                btn("فتح إعدادات الواي فاي") { open(Settings.ACTION_WIFI_SETTINGS) }
                btn("متابعة") { next() }.requestFocus()
            }
            3 -> {
                title("الحساب (اختياري)")
                body("يُحفظ على الجهاز فقط لعرض اسمك. لا يتصل بحساب جوجل")
                nameField = field("الاسم", prefs().getString("name", ""), InputType.TYPE_CLASS_TEXT)
                emailField = field("الإيميل", prefs().getString("email", ""), InputType.TYPE_TEXT_VARIATION_EMAIL_ADDRESS)
                btn("متابعة") { saveAccount(); next() }
                btn("تخطي") { next() }
            }
            4 -> chooseApps()
            else -> {
                title("كل شيء جاهز")
                body("اضغط زر Home واختر هذا اللانشر ثم \"دائماً\" ليصبح الواجهة الافتراضية")
                btn("ابدأ") {
                    prefs().edit().putStringSet("favs", favs).putBoolean("setup_done", true).apply()
                    startActivity(Intent(this, MainActivity::class.java))
                    finish()
                }.requestFocus()
            }
        }
    }

    private fun saveAccount() {
        prefs().edit()
            .putString("name", nameField?.text?.toString()?.trim() ?: "")
            .putString("email", emailField?.text?.toString()?.trim() ?: "")
            .apply()
    }

    private fun chooseApps() {
        title("اختر تطبيقاتك المفضلة")
        val cont = btn("متابعة") { next() }
        cont.requestFocus()
        val list = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL }
        loadApps().forEach { app ->
            val check = text(if (app.pkg in favs) "✓" else "", 20f)
            val row = LinearLayout(this).apply {
                gravity = Gravity.CENTER_VERTICAL
                setPadding(dp(16), dp(10), dp(16), dp(10))
                focusCard()
                addView(ImageView(context).apply { setImageDrawable(app.icon) }, LinearLayout.LayoutParams(dp(40), dp(40)))
                addView(text(app.label, 18f).apply { setPadding(dp(16), 0, dp(16), 0) }, LinearLayout.LayoutParams(0, -2, 1f))
                addView(check)
                setOnClickListener {
                    if (!favs.add(app.pkg)) favs.remove(app.pkg)
                    check.text = if (app.pkg in favs) "✓" else ""
                }
            }
            list.addView(row, LinearLayout.LayoutParams(-1, -2).apply { topMargin = dp(8) })
        }
        root.addView(ScrollView(this).apply { clipToPadding = false; setPadding(dp(8), dp(12), dp(8), dp(12)); addView(list) },
            LinearLayout.LayoutParams(dp(520), 0, 1f))
    }

    private fun open(action: String) {
        try { startActivity(Intent(action)) } catch (e: Exception) {
            Toast.makeText(this, "غير متاح على هذا الجهاز", Toast.LENGTH_SHORT).show()
        }
    }

    private fun title(s: String) = root.addView(text(s, 30f, WHITE, true).apply { gravity = Gravity.CENTER; setPadding(0, 0, 0, dp(12)) })
    private fun body(s: String) = root.addView(text(s, 18f, GRAY).apply { gravity = Gravity.CENTER; setPadding(0, 0, 0, dp(24)) })

    private fun btn(s: String, action: () -> Unit): TextView {
        val t = text(s, 20f).apply {
            gravity = Gravity.CENTER
            setPadding(dp(20), dp(14), dp(20), dp(14))
            focusCard()
            setOnClickListener { action() }
        }
        root.addView(t, LinearLayout.LayoutParams(dp(420), -2).apply { topMargin = dp(12) })
        return t
    }

    private fun field(hint: String, value: String?, type: Int): EditText {
        val e = EditText(this).apply {
            this.hint = hint
            setText(value ?: "")
            inputType = type
            setSingleLine(true)
            setTextColor(WHITE)
            setHintTextColor(GRAY)
            setPadding(dp(16), dp(12), dp(16), dp(12))
            background = shape(0xFF1E2538.toInt())
        }
        root.addView(e, LinearLayout.LayoutParams(dp(420), -2).apply { topMargin = dp(12) })
        return e
    }
}
END_OF_FILE_XYZ
mkdir -p 'app/src/main/java/com/example/tvlauncher'
cat > 'app/src/main/java/com/example/tvlauncher/Ui.kt' <<'END_OF_FILE_XYZ'
package com.example.tvlauncher

import android.content.Context
import android.content.Intent
import android.graphics.Typeface
import android.graphics.drawable.Drawable
import android.graphics.drawable.GradientDrawable
import android.graphics.drawable.StateListDrawable
import android.view.View
import android.widget.TextView

const val WHITE = 0xFFFFFFFF.toInt()
const val GRAY = 0xFFAAB3C8.toInt()
const val BG = 0xFF0F1420.toInt()

data class AppItem(val label: String, val pkg: String, val icon: Drawable)

fun Context.dp(v: Int): Int = (v * resources.displayMetrics.density).toInt()
fun Context.prefs() = getSharedPreferences("launcher", Context.MODE_PRIVATE)

fun Context.loadApps(): List<AppItem> {
    val pm = packageManager
    val result = LinkedHashMap<String, AppItem>()
    for (cat in listOf(Intent.CATEGORY_LEANBACK_LAUNCHER, Intent.CATEGORY_LAUNCHER)) {
        val i = Intent(Intent.ACTION_MAIN).addCategory(cat)
        for (ri in pm.queryIntentActivities(i, 0)) {
            val p = ri.activityInfo.packageName
            if (p == packageName || result.containsKey(p)) continue
            result[p] = AppItem(ri.loadLabel(pm).toString(), p, ri.loadIcon(pm))
        }
    }
    return result.values.sortedBy { it.label.lowercase() }
}

fun Context.openApp(pkg: String) {
    val pm = packageManager
    val i = pm.getLeanbackLaunchIntentForPackage(pkg) ?: pm.getLaunchIntentForPackage(pkg)
    if (i != null) {
        i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        prefs().edit().putString("last", pkg).apply()
        startActivity(i)
    }
}

fun Context.text(s: String, size: Float, color: Int = WHITE, bold: Boolean = false) =
    TextView(this).apply {
        text = s
        textSize = size
        setTextColor(color)
        if (bold) setTypeface(typeface, Typeface.BOLD)
    }

fun shape(color: Int, stroke: Int = 0, radius: Float = 16f) = GradientDrawable().apply {
    setColor(color)
    cornerRadius = radius
    if (stroke != 0) setStroke(4, stroke)
}

// بطاقة قابلة للتركيز بالريموت: تكبير + إطار أبيض عند التحديد
fun View.focusCard(base: Int = 0xFF1E2538.toInt()) {
    isFocusable = true
    isClickable = true
    background = StateListDrawable().apply {
        addState(intArrayOf(android.R.attr.state_focused), shape(0xFF3C4A6B.toInt(), WHITE))
        addState(intArrayOf(), shape(base))
    }
    val prev = onFocusChangeListener
    onFocusChangeListener = View.OnFocusChangeListener { v, f ->
        val s = if (f) 1.07f else 1f
        v.animate().scaleX(s).scaleY(s).setDuration(120).start()
        prev?.onFocusChange(v, f)
    }
}
END_OF_FILE_XYZ
