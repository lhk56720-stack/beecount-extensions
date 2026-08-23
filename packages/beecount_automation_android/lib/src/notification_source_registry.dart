final class NotificationSourceDescriptor {
  const NotificationSourceDescriptor({
    required this.id,
    required this.packageName,
    required this.displayName,
    required this.parserPhase,
  });

  final String id;
  final String packageName;
  final String displayName;
  final String parserPhase;
}

abstract final class NotificationSourceRegistry {
  static const List<NotificationSourceDescriptor> supported =
      <NotificationSourceDescriptor>[
    NotificationSourceDescriptor(
      id: 'wechat',
      packageName: 'com.tencent.mm',
      displayName: '微信',
      parserPhase: 'first',
    ),
    NotificationSourceDescriptor(
      id: 'alipay',
      packageName: 'com.eg.android.AlipayGphone',
      displayName: '支付宝',
      parserPhase: 'first',
    ),
    NotificationSourceDescriptor(
      id: 'unionpay',
      packageName: 'com.unionpay',
      displayName: '云闪付',
      parserPhase: 'second',
    ),
    NotificationSourceDescriptor(
      id: 'xiaomi_wallet',
      packageName: 'com.miui.tsmclient',
      displayName: '小米钱包',
      parserPhase: 'second',
    ),
    NotificationSourceDescriptor(
      id: 'jd',
      packageName: 'com.jingdong.app.mall',
      displayName: '京东',
      parserPhase: 'later',
    ),
    NotificationSourceDescriptor(
      id: 'meituan',
      packageName: 'com.sankuai.meituan',
      displayName: '美团',
      parserPhase: 'later',
    ),
    NotificationSourceDescriptor(
      id: 'douyin',
      packageName: 'com.ss.android.ugc.aweme',
      displayName: '抖音',
      parserPhase: 'later',
    ),
    NotificationSourceDescriptor(
      id: 'taobao',
      packageName: 'com.taobao.taobao',
      displayName: '淘宝',
      parserPhase: 'later',
    ),
  ];

  static NotificationSourceDescriptor? byPackageName(String packageName) {
    for (final source in supported) {
      if (source.packageName == packageName) return source;
    }
    return null;
  }
}
