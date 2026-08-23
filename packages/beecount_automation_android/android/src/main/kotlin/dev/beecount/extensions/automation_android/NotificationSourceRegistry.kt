package dev.beecount.extensions.automation_android

internal data class NativeNotificationSource(
    val id: String,
    val packageName: String,
    val displayName: String,
)

internal object NotificationSourceRegistry {
    val supported: List<NativeNotificationSource> = listOf(
        NativeNotificationSource("wechat", "com.tencent.mm", "微信"),
        NativeNotificationSource("alipay", "com.eg.android.AlipayGphone", "支付宝"),
        NativeNotificationSource("unionpay", "com.unionpay", "云闪付"),
        NativeNotificationSource("xiaomi_wallet", "com.miui.tsmclient", "小米钱包"),
        NativeNotificationSource("jd", "com.jingdong.app.mall", "京东"),
        NativeNotificationSource("meituan", "com.sankuai.meituan", "美团"),
        NativeNotificationSource("douyin", "com.ss.android.ugc.aweme", "抖音"),
        NativeNotificationSource("taobao", "com.taobao.taobao", "淘宝"),
    )

    private val byPackage = supported.associateBy { it.packageName }

    fun sourceFor(packageName: String): NativeNotificationSource? = byPackage[packageName]

    fun isSupported(packageName: String): Boolean = byPackage.containsKey(packageName)
}
