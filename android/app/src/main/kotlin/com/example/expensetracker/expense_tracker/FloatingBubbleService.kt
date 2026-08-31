package com.example.expensetracker.expense_tracker

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.database.sqlite.SQLiteDatabase
import android.graphics.Color
import android.graphics.PixelFormat
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.util.DisplayMetrics
import android.view.*
import android.view.inputmethod.InputMethodManager
import android.widget.Button
import android.widget.EditText
import android.widget.ImageButton
import android.widget.LinearLayout
import androidx.core.app.NotificationCompat
import java.io.File
import java.text.SimpleDateFormat
import java.util.*
import kotlin.math.abs

class FloatingBubbleService : Service() {

    private lateinit var windowManager: WindowManager
    private var bubbleView: View? = null
    private var quickExpenseView: View? = null

    private var screenWidth = 0
    private var screenHeight = 0
    private var bubbleSizePx = 0

    private var isExpanded = false
    private var selectedCategoryId = 1
    private var selectedCategoryName = "Petrol"
    private var selectedPaymentMethod = "UPI"

    companion object {
        var isRunning = false
        const val ACTION_EXPENSE_ADDED = "com.example.expensetracker.expense_tracker.EXPENSE_ADDED"
        const val ACTION_SHOW_BUBBLE = "com.example.expensetracker.expense_tracker.SHOW_BUBBLE"
        const val ACTION_HIDE_BUBBLE = "com.example.expensetracker.expense_tracker.HIDE_BUBBLE"
        private const val CHANNEL_ID = "floating_bubble_channel"
        private const val NOTIFICATION_ID = 1001
        private const val PREFS_NAME = "bubble_prefs"
        private const val KEY_EDGE = "bubble_edge"
        private const val KEY_Y_PERCENT = "bubble_y_percent"
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent != null) {
            when (intent.action) {
                ACTION_HIDE_BUBBLE -> {
                    collapseQuickExpense()
                    bubbleView?.visibility = View.GONE
                }
                ACTION_SHOW_BUBBLE -> {
                    if (!isExpanded) {
                        bubbleView?.visibility = View.VISIBLE
                    }
                }
            }
        }
        return START_STICKY
    }

    override fun onCreate() {
        super.onCreate()
        isRunning = true
        windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager
        
        calculateScreenMetrics()
        createNotificationChannel()
        startForeground(NOTIFICATION_ID, buildNotification())

        createBubbleView()
    }

    private fun calculateScreenMetrics() {
        val displayMetrics = DisplayMetrics()
        windowManager.defaultDisplay.getMetrics(displayMetrics)
        screenWidth = displayMetrics.widthPixels
        screenHeight = displayMetrics.heightPixels
        bubbleSizePx = (42 * displayMetrics.density).toInt()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Quick Add Floating Bubble",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Running floating overlay for quick expense logging"
            }
            val manager = getSystemService(NotificationManager::class.java)
            manager?.createNotificationChannel(channel)
        }
    }

    private fun buildNotification(): Notification {
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Expense Tracker Quick Add")
            .setContentText("Tap bubble to quickly log expenses")
            .setSmallIcon(android.R.drawable.ic_input_add)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setOngoing(true)
            .build()
    }

    private fun createBubbleView() {
        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val savedEdge = prefs.getString(KEY_EDGE, "right") ?: "right"
        val savedYPercent = prefs.getFloat(KEY_Y_PERCENT, 0.5f)

        val layoutType = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_PHONE
        }

        val initialX = if (savedEdge == "left") 0 else (screenWidth - bubbleSizePx)
        val initialY = (screenHeight * savedYPercent).toInt()

        val params = WindowManager.LayoutParams(
            bubbleSizePx,
            bubbleSizePx,
            layoutType,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            x = initialX
            y = initialY
        }

        val inflater = getSystemService(Context.LAYOUT_INFLATER_SERVICE) as LayoutInflater
        bubbleView = inflater.inflate(R.layout.bubble_layout, null)

        var initialTouchX = 0f
        var initialTouchY = 0f
        var initialParamsX = 0
        var initialParamsY = 0
        var totalDragDistance = 0f

        bubbleView?.setOnTouchListener { _, event ->
            when (event.action) {
                MotionEvent.ACTION_DOWN -> {
                    initialTouchX = event.rawX
                    initialTouchY = event.rawY
                    initialParamsX = params.x
                    initialParamsY = params.y
                    totalDragDistance = 0f
                    true
                }
                MotionEvent.ACTION_MOVE -> {
                    val dx = event.rawX - initialTouchX
                    val dy = event.rawY - initialTouchY
                    totalDragDistance += abs(dx) + abs(dy)

                    params.x = (initialParamsX + dx).toInt()
                    params.y = (initialParamsY + dy).toInt()
                    
                    try {
                        windowManager.updateViewLayout(bubbleView, params)
                    } catch (_: Exception) {}
                    true
                }
                MotionEvent.ACTION_UP -> {
                    if (totalDragDistance < 15) {
                        expandQuickExpense(params.y)
                    } else {
                        val snapToRight = (params.x + bubbleSizePx / 2) > (screenWidth / 2)
                        val targetX = if (snapToRight) (screenWidth - bubbleSizePx) else 0
                        params.x = targetX

                        try {
                            windowManager.updateViewLayout(bubbleView, params)
                        } catch (_: Exception) {}

                        val newEdge = if (snapToRight) "right" else "left"
                        val newYPercent = (params.y.toFloat() / screenHeight).coerceIn(0.1f, 0.85f)
                        prefs.edit()
                            .putString(KEY_EDGE, newEdge)
                            .putFloat(KEY_Y_PERCENT, newYPercent)
                            .apply()
                    }
                    true
                }
                else -> false
            }
        }

        try {
            bubbleView?.visibility = View.GONE
            windowManager.addView(bubbleView, params)
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun expandQuickExpense(bubbleY: Int) {
        if (isExpanded || quickExpenseView != null) return
        isExpanded = true

        bubbleView?.visibility = View.GONE

        val layoutType = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_PHONE
        }

        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val savedEdge = prefs.getString(KEY_EDGE, "right") ?: "right"

        val density = resources.displayMetrics.density
        val cardWidthPx = (310 * density).toInt()

        val params = WindowManager.LayoutParams(
            cardWidthPx,
            WindowManager.LayoutParams.WRAP_CONTENT,
            layoutType,
            WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or WindowManager.LayoutParams.FLAG_WATCH_OUTSIDE_TOUCH,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP or (if (savedEdge == "left") Gravity.START else Gravity.END)
            x = (8 * density).toInt()
            y = (60 * density).toInt()
            softInputMode = WindowManager.LayoutParams.SOFT_INPUT_ADJUST_RESIZE or WindowManager.LayoutParams.SOFT_INPUT_STATE_UNCHANGED
        }

        val inflater = getSystemService(Context.LAYOUT_INFLATER_SERVICE) as LayoutInflater
        quickExpenseView = inflater.inflate(R.layout.quick_expense_layout, null)

        val etAmount = quickExpenseView?.findViewById<EditText>(R.id.et_amount)
        val etDescription = quickExpenseView?.findViewById<EditText>(R.id.et_description)
        val btnClose = quickExpenseView?.findViewById<ImageButton>(R.id.btn_close)
        val btnSave = quickExpenseView?.findViewById<Button>(R.id.btn_save)
        val btnPaymentUpi = quickExpenseView?.findViewById<Button>(R.id.btn_payment_upi)
        val btnPaymentCash = quickExpenseView?.findViewById<Button>(R.id.btn_payment_cash)
        val container = quickExpenseView?.findViewById<LinearLayout>(R.id.category_container)

        selectedPaymentMethod = "UPI"
        btnPaymentUpi?.backgroundTintList = android.content.res.ColorStateList.valueOf(Color.parseColor("#6366F1"))
        btnPaymentUpi?.setTextColor(Color.WHITE)
        btnPaymentCash?.backgroundTintList = android.content.res.ColorStateList.valueOf(Color.parseColor("#0F172A"))
        btnPaymentCash?.setTextColor(Color.parseColor("#94A3B8"))

        btnPaymentUpi?.setOnClickListener {
            selectedPaymentMethod = "UPI"
            btnPaymentUpi.backgroundTintList = android.content.res.ColorStateList.valueOf(Color.parseColor("#6366F1"))
            btnPaymentUpi.setTextColor(Color.WHITE)
            btnPaymentCash?.backgroundTintList = android.content.res.ColorStateList.valueOf(Color.parseColor("#0F172A"))
            btnPaymentCash?.setTextColor(Color.parseColor("#94A3B8"))
        }

        btnPaymentCash?.setOnClickListener {
            selectedPaymentMethod = "Cash"
            btnPaymentCash.backgroundTintList = android.content.res.ColorStateList.valueOf(Color.parseColor("#6366F1"))
            btnPaymentCash.setTextColor(Color.WHITE)
            btnPaymentUpi?.backgroundTintList = android.content.res.ColorStateList.valueOf(Color.parseColor("#0F172A"))
            btnPaymentUpi?.setTextColor(Color.parseColor("#94A3B8"))
        }

        val activeCategories = loadActiveCategoriesFromDb()
        if (activeCategories.isNotEmpty()) {
            selectedCategoryName = activeCategories.first().second
            selectedCategoryId = activeCategories.first().first
        }

        container?.removeAllViews()
        val allCategoryButtons = mutableListOf<Triple<Button, Int, String>>()

        activeCategories.chunked(3).forEach { rowList ->
            val rowLayout = LinearLayout(this).apply {
                orientation = LinearLayout.HORIZONTAL
                layoutParams = LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.MATCH_PARENT,
                    LinearLayout.LayoutParams.WRAP_CONTENT
                ).apply {
                    bottomMargin = (6 * density).toInt()
                }
            }

            rowList.forEachIndexed { index, (catId, catName) ->
                val btn = Button(this).apply {
                    text = catName
                    textSize = 11f
                    maxLines = 1
                    ellipsize = android.text.TextUtils.TruncateAt.END
                    setPadding((4 * density).toInt(), 0, (4 * density).toInt(), 0)

                    layoutParams = LinearLayout.LayoutParams(
                        0,
                        (36 * density).toInt(),
                        1f
                    ).apply {
                        if (index > 0) marginStart = (4 * density).toInt()
                        if (index < rowList.size - 1) marginEnd = (4 * density).toInt()
                    }
                }

                if (catName == selectedCategoryName) {
                    btn.setBackgroundColor(Color.parseColor("#6366F1"))
                    btn.setTextColor(Color.WHITE)
                } else {
                    btn.setBackgroundColor(Color.parseColor("#0F172A"))
                    btn.setTextColor(Color.parseColor("#94A3B8"))
                }

                allCategoryButtons.add(Triple(btn, catId, catName))

                btn.setOnClickListener {
                    selectedCategoryName = catName
                    selectedCategoryId = catId
                    allCategoryButtons.forEach { (b, _, cName) ->
                        if (cName == selectedCategoryName) {
                            b.setBackgroundColor(Color.parseColor("#6366F1"))
                            b.setTextColor(Color.WHITE)
                        } else {
                            b.setBackgroundColor(Color.parseColor("#0F172A"))
                            b.setTextColor(Color.parseColor("#94A3B8"))
                        }
                    }
                }

                rowLayout.addView(btn)
            }

            container?.addView(rowLayout)
        }

        btnClose?.setOnClickListener {
            collapseQuickExpense()
        }

        btnSave?.setOnClickListener {
            val amountText = etAmount?.text?.toString()?.trim() ?: ""
            val noteText = etDescription?.text?.toString()?.trim() ?: ""
            val valDouble = amountText.toDoubleOrNull()
            if (valDouble != null && valDouble > 0) {
                saveExpenseToDatabase(valDouble, selectedCategoryName, noteText)
                collapseQuickExpense()
            }
        }

        try {
            windowManager.addView(quickExpenseView, params)

            Handler(Looper.getMainLooper()).postDelayed({
                etAmount?.requestFocus()
                val imm = getSystemService(Context.INPUT_METHOD_SERVICE) as InputMethodManager
                imm.showSoftInput(etAmount, InputMethodManager.SHOW_IMPLICIT)
            }, 100)

        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun loadActiveCategoriesFromDb(): List<Pair<Int, String>> {
        val result = mutableListOf<Pair<Int, String>>()
        try {
            val dbFile = findDatabaseFile() ?: return getFallbackCategories()
            val db = SQLiteDatabase.openDatabase(dbFile.path, null, SQLiteDatabase.OPEN_READONLY)
            val cursor = db.rawQuery("SELECT id, name FROM categories ORDER BY sort_order ASC, id ASC", null)
            while (cursor.moveToNext()) {
                val id = cursor.getInt(0)
                val name = cursor.getString(1)
                result.add(id to name)
            }
            cursor.close()
            db.close()
        } catch (e: Exception) {
            e.printStackTrace()
        }
        if (result.isEmpty()) {
            return getFallbackCategories()
        }
        return result
    }

    private fun getFallbackCategories(): List<Pair<Int, String>> {
        return listOf(
            1 to "Petrol",
            2 to "Groceries",
            3 to "Medicine",
            4 to "Veg & Fruits",
            5 to "Travel",
            6 to "Transfer",
            7 to "Dress",
            8 to "Investment",
            9 to "Insurance",
            10 to "Misc"
        )
    }

    private fun collapseQuickExpense() {
        if (!isExpanded) return
        
        val etAmount = quickExpenseView?.findViewById<EditText>(R.id.et_amount)
        if (etAmount != null) {
            val imm = getSystemService(Context.INPUT_METHOD_SERVICE) as InputMethodManager
            imm.hideSoftInputFromWindow(etAmount.windowToken, 0)
        }

        if (quickExpenseView != null) {
            try {
                windowManager.removeView(quickExpenseView)
            } catch (_: Exception) {}
            quickExpenseView = null
        }

        isExpanded = false
        bubbleView?.visibility = View.VISIBLE
    }

    private fun saveExpenseToDatabase(amountDouble: Double, categoryName: String, description: String = "") {
        try {
            val dbFile = findDatabaseFile() ?: return
            dbFile.parentFile?.mkdirs()

            val db = SQLiteDatabase.openOrCreateDatabase(dbFile, null)
            val now = Date()
            val nowMillis = now.time

            val dateFormat = SimpleDateFormat("yyyy-MM-dd", Locale.US)
            val timeFormat = SimpleDateFormat("HH:mm", Locale.getDefault())

            val categoryId = resolveCategoryId(db, categoryName)
            val accountId = resolvePaymentAccountId(db, selectedPaymentMethod)

            val values = ContentValues().apply {
                put("amount", (amountDouble * 100).toLong())
                put("category_id", categoryId)
                put("account_id", accountId)
                put("note", if (description.isNotEmpty()) description else "Quick Add via Bubble")
                put("date", dateFormat.format(now))
                put("time", timeFormat.format(now))
                put("created_at", nowMillis)
                put("updated_at", nowMillis)
            }

            db.insert("expenses", null, values)
            db.close()

            sendBroadcast(Intent(ACTION_EXPENSE_ADDED))
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun resolveCategoryId(db: SQLiteDatabase, categoryName: String): Int {
        try {
            val cursor = db.rawQuery(
                "SELECT id FROM categories WHERE LOWER(name) = ? OR LOWER(name) LIKE ? ORDER BY id ASC LIMIT 1",
                arrayOf(categoryName.lowercase(), "%${categoryName.lowercase()}%")
            )
            if (cursor.moveToFirst()) {
                val id = cursor.getInt(0)
                cursor.close()
                return id
            }
            cursor.close()
        } catch (_: Exception) {}

        return selectedCategoryId
    }

    private fun resolvePaymentAccountId(db: SQLiteDatabase, paymentMethod: String): Int {
        try {
            if (paymentMethod.contains("Cash", ignoreCase = true)) {
                val cursor = db.rawQuery(
                    "SELECT id FROM accounts WHERE LOWER(name) LIKE '%cash%' ORDER BY id ASC LIMIT 1",
                    null
                )
                if (cursor.moveToFirst()) {
                    val id = cursor.getInt(0)
                    cursor.close()
                    return id
                }
                cursor.close()
            } else {
                val cursor = db.rawQuery(
                    "SELECT id FROM accounts WHERE is_default = 1 OR LOWER(name) LIKE '%upi%' OR LOWER(name) LIKE '%bank%' ORDER BY is_default DESC, id ASC LIMIT 1",
                    null
                )
                if (cursor.moveToFirst()) {
                    val id = cursor.getInt(0)
                    cursor.close()
                    return id
                }
                cursor.close()
            }
        } catch (_: Exception) {}

        return resolveDefaultAccountId(db)
    }

    private fun resolveDefaultAccountId(db: SQLiteDatabase): Int {
        try {
            val cursor = db.rawQuery(
                "SELECT id FROM accounts WHERE is_default = 1 LIMIT 1",
                null
            )
            if (cursor.moveToFirst()) {
                val id = cursor.getInt(0)
                cursor.close()
                return id
            }
            cursor.close()

            val fallbackCursor = db.rawQuery("SELECT id FROM accounts ORDER BY id ASC LIMIT 1", null)
            if (fallbackCursor.moveToFirst()) {
                val id = fallbackCursor.getInt(0)
                fallbackCursor.close()
                return id
            }
            fallbackCursor.close()
        } catch (_: Exception) {}

        return 1
    }

    private fun findDatabaseFile(): File? {
        val appFlutterDb = File(filesDir.parentFile, "app_flutter/expense_tracker.db")
        if (appFlutterDb.exists()) return appFlutterDb

        val docDb = File(filesDir, "expense_tracker.db")
        if (docDb.exists()) return docDb

        val sysDb = getDatabasePath("expense_tracker.db")
        if (sysDb.exists()) return sysDb

        val parentDb = File(filesDir.parentFile, "databases/expense_tracker.db")
        if (parentDb.exists()) return parentDb

        appFlutterDb.parentFile?.mkdirs()
        return appFlutterDb
    }

    override fun onDestroy() {
        isRunning = false
        if (quickExpenseView != null) {
            try {
                windowManager.removeView(quickExpenseView)
            } catch (_: Exception) {}
        }
        if (bubbleView != null) {
            try {
                windowManager.removeView(bubbleView)
            } catch (_: Exception) {}
        }
        super.onDestroy()
    }
}
