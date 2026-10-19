import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// 抖音 / 快手解析结果（直链有时效）
enum DouyinMediaType { video, images }

class DouyinResolveResult {
  const DouyinResolveResult({
    required this.awemeId,
    required this.videoUrl,
    this.title = '',
    this.coverUrl,
    this.source = '',
    this.platform = ShortVideoPlatform.douyin,
    this.mediaType = DouyinMediaType.video,
    this.imageUrls = const [],
  });

  /// 视频 ID（抖音 aweme_id / 快手 photoId / 图文 noteId）
  final String awemeId;
  final String videoUrl;
  final String title;
  final String? coverUrl;
  final String source;
  final ShortVideoPlatform platform;
  final DouyinMediaType mediaType;
  final List<String> imageUrls;

  bool get isImageNote =>
      mediaType == DouyinMediaType.images && imageUrls.isNotEmpty;
}

enum ShortVideoPlatform { douyin, kuaishou }

/// 快手短链跟跳结果
class KuaishouResolveMeta {
  const KuaishouResolveMeta({
    required this.photoId,
    required this.finalUrl,
    required this.isAtlas,
  });

  final String photoId;
  final String finalUrl;

  /// 图文/图集（非视频）
  final bool isAtlas;
}

/// 抖音 / 快手分享链接解析
///
/// - 抖音：WebView 自行访问（可选 yt-dlp + Cookie）
/// - 快手：HTTP 拉分享页 INIT_STATE，无需浏览器 Cookie
class DouyinResolveService {
  DouyinResolveService._();

  static final RegExp _douyinShareUrlRe = RegExp(
    r'https?://(?:'
    r'v\.douyin\.com/[A-Za-z0-9_-]+/?'
    r'|(?:www\.)?douyin\.com/(?:video|note)/\d+[^\s]*'
    r'|(?:www\.)?iesdouyin\.com/share/(?:note|video)/\d+[^\s]*'
    r')',
    caseSensitive: false,
  );
  static final RegExp _kuaishouShareUrlRe = RegExp(
    r'https?://(?:'
    r'v\.kuaishou\.com/[A-Za-z0-9_-]+/?'
    r'|v\.m\.chenzhongtech\.com/[^\s]*'
    r'|(?:www\.)?kuaishou\.com/[^\s]*'
    r'|m\.gifshow\.com/[^\s]*'
    r')',
    caseSensitive: false,
  );
  static final RegExp _awemeIdRe = RegExp(r'/video/(\d+)');
  static final RegExp _noteIdRe = RegExp(r'/(?:share/)?note/(\d+)');
  static final RegExp _photoIdRe = RegExp(
    r'(?:/photo/|photoId=|/short-video/)([A-Za-z0-9_-]+)',
  );

  static const String userAgent =
      'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) '
      'AppleWebKit/537.36 (KHTML, like Gecko) '
      'Chrome/120.0.0.0 Safari/537.36';

  static const String mobileUserAgent =
      'Mozilla/5.0 (iPhone; CPU iPhone OS 16_6 like Mac OS X) '
      'AppleWebKit/605.1.15 (KHTML, like Gecko) '
      'Version/16.6 Mobile/15E148 Safari/604.1';

  static void _log(String msg) => debugPrint('[去水印] $msg');

  static ShortVideoPlatform? detectPlatform(String text) {
    if (_kuaishouShareUrlRe.hasMatch(text) ||
        text.contains('kuaishou.com') ||
        text.contains('chenzhongtech.com') ||
        text.contains('gifshow.com') ||
        text.contains('快手')) {
      // 文案里同时有抖音时，以实际 URL 为准
      final ks = _kuaishouShareUrlRe.firstMatch(text)?.group(0);
      final dy = _douyinShareUrlRe.firstMatch(text)?.group(0);
      if (ks != null && dy == null) return ShortVideoPlatform.kuaishou;
      if (dy != null && ks == null) return ShortVideoPlatform.douyin;
      if (ks != null) return ShortVideoPlatform.kuaishou;
      if (text.contains('快手') && !text.contains('抖音')) {
        return ShortVideoPlatform.kuaishou;
      }
    }
    if (_douyinShareUrlRe.hasMatch(text) ||
        text.contains('douyin.com') ||
        text.contains('iesdouyin.com') ||
        text.contains('抖音') ||
        text.contains('Dou音')) {
      return ShortVideoPlatform.douyin;
    }
    return null;
  }

  /// 注入：拦截 aweme/detail（须尽早执行）
  static const String captureHookJs = r'''
(function(){
  if (window.__dyHooked) return;
  window.__dyHooked = true;
  window.__dyCapture = {video:'', cover:'', title:'', source:'', images:[]};

  function scoreUrl(u){
    if (!u || typeof u !== 'string') return -999;
    if (u.indexOf('blob:') === 0) return -999;
    if (u.indexOf('http') !== 0) return -999;
    if (u.indexOf('playwm') >= 0) return -999; // 平台水印流
    var s = 0;
    if (u.indexOf('watermark=0') >= 0) s += 50;
    if (u.indexOf('unwatermarked') >= 0) s += 40;
    if (u.indexOf('douyinvod') >= 0 || u.indexOf('bytevod') >= 0) s += 15;
    if (u.indexOf('365yg.com') >= 0) s += 10;
    if (u.indexOf('/aweme/v1/play/') >= 0) s += 25;
    if (u.indexOf('mime_type=video_mp4') >= 0) s += 5;
    return s;
  }

  function pickUrl(addr){
    try {
      if (!addr || !addr.url_list || !addr.url_list.length) return '';
      var best = '';
      var bestScore = -1;
      for (var i = 0; i < addr.url_list.length; i++) {
        var u = addr.url_list[i] || '';
        var sc = scoreUrl(u);
        if (sc > bestScore) {
          bestScore = sc;
          best = u;
        }
      }
      return bestScore >= 0 ? best : '';
    } catch (e) { return ''; }
  }

  function firstUrl(addr){ return pickUrl(addr); }

  function pickVideo(v){
    // play_addr 多为去平台标流；download_addr 反而常带下载角标
    var parts = [
      {n:'play_addr', a:v.play_addr},
      {n:'play_addr_h264', a:v.play_addr_h264},
      {n:'download_addr', a:v.download_addr}
    ];
    try {
      if (v.bit_rate && v.bit_rate.length) {
        for (var bi = 0; bi < v.bit_rate.length; bi++) {
          var br = v.bit_rate[bi] || {};
          parts.push({n:'bit_rate', a: br.play_addr});
        }
      }
    } catch (e) {}

    var best = '';
    var bestScore = -1;
    var bestName = '';
    for (var i = 0; i < parts.length; i++) {
      var u = pickUrl(parts[i].a);
      var sc = scoreUrl(u);
      // 同质量时优先 play_addr，压低 download_addr（后者常带平台角标）
      if (parts[i].n === 'play_addr' || parts[i].n === 'play_addr_h264') sc += 8;
      if (parts[i].n === 'download_addr') sc -= 12;
      if (sc > bestScore) {
        bestScore = sc;
        best = u;
        bestName = parts[i].n;
      }
    }

    // 仅在没有 CDN 直链时，用 uri 拼 watermark=0 播放接口（该接口常需 Cookie）
    if (!best) {
      try {
        var uri = (v.play_addr && v.play_addr.uri)
          || (v.download_addr && v.download_addr.uri)
          || '';
        if (uri) {
          best = 'https://www.douyin.com/aweme/v1/play/?video_id='
            + encodeURIComponent(uri)
            + '&ratio=default&line=0&improve_bitrate=1&watermark=0';
          bestName = 'play_api_wm0';
        }
      } catch (e) {}
    }
    return {url: best, field: bestName};
  }

  function grab(text){
    try {
      if (!text || text.indexOf('aweme_detail') < 0) return;
      var j = JSON.parse(text);
      var d = j.aweme_detail;
      if (!d) return;

      if (d.desc) window.__dyCapture.title = d.desc;

      // 图文笔记：images 列表（无 video 也要处理）
      if (d.images && d.images.length) {
        var imgs = [];
        for (var k = 0; k < d.images.length; k++) {
          var it = d.images[k] || {};
          var iu = '';
          if (it.download_url_list && it.download_url_list.length) {
            iu = it.download_url_list[0];
          } else if (it.url_list && it.url_list.length) {
            iu = it.url_list[0];
          } else {
            iu = pickUrl(it)
              || pickUrl(it.download_url)
              || pickUrl(it.origin_url)
              || pickUrl(it.display_image)
              || '';
          }
          if (iu && iu.indexOf('http') === 0) imgs.push(iu);
        }
        if (imgs.length) {
          window.__dyCapture.images = imgs;
          window.__dyCapture.cover = imgs[0];
          window.__dyCapture.source = 'detail-images';
        }
      }

      var v = d.video;
      if (!v) return;
      var picked = pickVideo(v);
      var cover = pickUrl(v.origin_cover) || pickUrl(v.cover) || '';
      if (picked.url) {
        window.__dyCapture.video = picked.url;
        window.__dyCapture.source = 'detail/' + (picked.field || 'unknown');
      }
      if (cover && !window.__dyCapture.cover) window.__dyCapture.cover = cover;
    } catch (e) {}
  }

  try {
    var ofetch = window.fetch;
    window.fetch = function(){
      var args = arguments;
      return ofetch.apply(this, args).then(function(res){
        try {
          var req = args[0];
          var u = (typeof req === 'string') ? req : (req && req.url) || '';
          if (u && u.indexOf('aweme') >= 0) {
            res.clone().text().then(function(t){
              if (t && (t.indexOf('aweme_detail') >= 0 || t.indexOf('"images"') >= 0)) {
                grab(t);
              }
            });
          }
        } catch (e) {}
        return res;
      });
    };
  } catch (e) {}

  try {
    var open = XMLHttpRequest.prototype.open;
    var send = XMLHttpRequest.prototype.send;
    XMLHttpRequest.prototype.open = function(method, url){
      this.__dyUrl = url;
      return open.apply(this, arguments);
    };
    XMLHttpRequest.prototype.send = function(){
      this.addEventListener('load', function(){
        try {
          if (this.__dyUrl && String(this.__dyUrl).indexOf('aweme') >= 0) {
            grab(this.responseText);
          }
        } catch (e) {}
      });
      return send.apply(this, arguments);
    };
  } catch (e) {}
})();
''';

  /// 快手：拦截 graphql / 读取 video / 图集 atlas
  static const String kuaishouCaptureHookJs = r'''
(function(){
  if (window.__ksHooked) return;
  window.__ksHooked = true;
  if (!window.__dyCapture) {
    window.__dyCapture = {video:'', cover:'', title:'', source:'', images:[]};
  }
  if (!window.__dyCapture.images) window.__dyCapture.images = [];

  function okMp4(u){
    if (!u || typeof u !== 'string') return false;
    if (u.indexOf('http') !== 0) return false;
    if (u.indexOf('_b_') >= 0 || u.indexOf('tt=b') >= 0) return false;
    if (u.indexOf('watermark') >= 0) return false;
    return u.indexOf('.mp4') >= 0
      || u.indexOf('photo-video') >= 0
      || (u.indexOf('kwaicdn.com') >= 0 && u.indexOf('.mp4') >= 0);
  }

  function okAtlas(u){
    if (!u || typeof u !== 'string') return false;
    if (u.indexOf('http') !== 0) return false;
    if (u.indexOf('uhead') >= 0 || u.indexOf('emotion') >= 0) return false;
    if (u.indexOf('avatar') >= 0) return false;
    return u.indexOf('/ufile/atlas/') >= 0
      || (u.indexOf('yximgs.com') >= 0 && (u.indexOf('.jpg') >= 0 || u.indexOf('.jpeg') >= 0 || u.indexOf('.webp') >= 0 || u.indexOf('.png') >= 0) && u.indexOf('/ufile/') >= 0);
  }

  function pushAtlas(u){
    if (!okAtlas(u)) return;
    var key = u.split('?')[0];
    var list = window.__dyCapture.images;
    for (var i = 0; i < list.length; i++) {
      if (list[i].split('?')[0] === key) return;
    }
    list.push(u);
    window.__dyCapture.source = window.__dyCapture.source || 'atlas';
    if (!window.__dyCapture.cover) window.__dyCapture.cover = u;
  }

  function grabKs(text){
    try {
      if (!text) return;
      var j = JSON.parse(text);
      var detail = j.data && j.data.visionVideoDetail;
      if (detail && detail.photo) {
        var p = detail.photo;
        if (p.photoUrl && okMp4(p.photoUrl)) {
          window.__dyCapture.video = p.photoUrl;
          window.__dyCapture.source = 'graphql';
        }
        if (p.coverUrl) window.__dyCapture.cover = p.coverUrl;
        if (p.caption) window.__dyCapture.title = p.caption;
      }
      // 图集 URL
      var reImg = /https:\/\/[^"\\]+\/ufile\/atlas\/[^"\\]+/g;
      var m;
      while ((m = reImg.exec(text)) !== null) pushAtlas(m[0]);
      if (!window.__dyCapture.video) {
        var re = /https:\/\/[^"\\]+\.mp4[^"\\]*/g;
        while ((m = re.exec(text)) !== null) {
          if (okMp4(m[0])) {
            window.__dyCapture.video = m[0];
            window.__dyCapture.source = 'json';
            break;
          }
        }
      }
    } catch (e) {}
  }

  function pollMedia(){
    try {
      var v = document.querySelector('video');
      if (v) {
        var src = v.currentSrc || v.src || '';
        if (okMp4(src)) {
          window.__dyCapture.video = src;
          window.__dyCapture.source = window.__dyCapture.source || 'video';
        }
      }
      var imgs = document.querySelectorAll('img');
      for (var i = 0; i < imgs.length; i++) {
        pushAtlas(imgs[i].src || '');
        pushAtlas(imgs[i].currentSrc || '');
      }
      try {
        var entries = performance.getEntriesByType('resource');
        for (var r = 0; r < entries.length; r++) pushAtlas(entries[r].name || '');
      } catch (e) {}
      if (!window.__dyCapture.title) {
        var t = (document.title || '').replace(/\s*-\s*快手\s*$/, '').trim();
        if (t && t !== '快手') window.__dyCapture.title = t;
      }
    } catch (e) {}
  }
  setInterval(pollMedia, 400);
  pollMedia();

  try {
    var ofetch = window.fetch;
    window.fetch = function(){
      var args = arguments;
      return ofetch.apply(this, args).then(function(res){
        try {
          var req = args[0];
          var u = (typeof req === 'string') ? req : (req && req.url) || '';
          if (u && (u.indexOf('graphql') >= 0 || u.indexOf('photo') >= 0 || u.indexOf('rest') >= 0)) {
            res.clone().text().then(grabKs);
          }
        } catch (e) {}
        return res;
      });
    };
  } catch (e) {}

  try {
    var open = XMLHttpRequest.prototype.open;
    var send = XMLHttpRequest.prototype.send;
    XMLHttpRequest.prototype.open = function(method, url){
      this.__ksUrl = url;
      return open.apply(this, arguments);
    };
    XMLHttpRequest.prototype.send = function(){
      this.addEventListener('load', function(){
        try {
          var u = String(this.__ksUrl || '');
          if (u.indexOf('graphql') >= 0 || u.indexOf('photo') >= 0 || u.indexOf('rest') >= 0) {
            grabKs(this.responseText);
          }
        } catch (e) {}
      });
      return send.apply(this, arguments);
    };
  } catch (e) {}
})();
''';

  /// 轮询读取捕获结果
  static const String readCaptureJs = r'''
(function(){
  function scoreUrl(u){
    if (!u || typeof u !== 'string') return -999;
    if (u.indexOf('blob:') === 0) return -999;
    if (u.indexOf('http') !== 0) return -999;
    if (u.indexOf('playwm') >= 0) return -999;
    var s = 0;
    if (u.indexOf('watermark=0') >= 0) s += 50;
    if (u.indexOf('unwatermarked') >= 0) s += 40;
    if (u.indexOf('douyinvod') >= 0 || u.indexOf('bytevod') >= 0) s += 15;
    if (u.indexOf('365yg.com') >= 0) s += 10;
    if (u.indexOf('/aweme/v1/play/') >= 0) s += 25;
    if (u.indexOf('mime_type=video_mp4') >= 0) s += 5;
    return s;
  }

  function okVideo(u){
    if (!u || typeof u !== 'string') return false;
    if (u.indexOf('blob:') === 0) return false;
    if (u.indexOf('playwm') >= 0) return false;
    if (u.indexOf('_b_') >= 0 || u.indexOf('tt=b') >= 0) return false;
    if (u.indexOf('http') !== 0) return false;
    if (u.indexOf('media-audio') >= 0) return false;
    if (u.indexOf('.js') >= 0 && u.indexOf('mime_type=video_mp4') < 0) return false;
    return u.indexOf('douyinvod') >= 0
      || u.indexOf('bytevod') >= 0
      || u.indexOf('365yg.com') >= 0
      || u.indexOf('kwaicdn.com') >= 0
      || u.indexOf('photo-video') >= 0
      || u.indexOf('/aweme/v1/play/') >= 0
      || (u.indexOf('.mp4') >= 0 && u.indexOf('yximgs.com') >= 0)
      || (u.indexOf('mime_type=video_mp4') >= 0 && u.indexOf('/video/') >= 0);
  }

  function okImage(u){
    if (!u || typeof u !== 'string') return false;
    if (u.indexOf('http') !== 0) return false;
    if (u.indexOf('avatar') >= 0 || u.indexOf('100x100') >= 0) return false;
    if (u.indexOf('aweme_comment') >= 0 || u.indexOf('sticker') >= 0) return false;
    if (u.indexOf('pcweb_cover') >= 0 || u.indexOf('noop.jpeg') >= 0) return false;
    if (u.indexOf('uhead') >= 0 || u.indexOf('emotion') >= 0) return false;
    if (u.indexOf('biz_tag=aweme_images') >= 0) return true;
    if (u.indexOf('tplv-dy-aweme-images') >= 0) return true;
    if (u.indexOf('tos-cn-i-') >= 0 && u.indexOf('image-cut-tos') < 0) return true;
    // 快手图集
    if (u.indexOf('/ufile/atlas/') >= 0) return true;
    if (u.indexOf('yximgs.com') >= 0 && u.indexOf('/ufile/') >= 0 &&
        (u.indexOf('.jpg') >= 0 || u.indexOf('.jpeg') >= 0 || u.indexOf('.webp') >= 0 || u.indexOf('.png') >= 0)) {
      return true;
    }
    return false;
  }

  var out = {video:'', cover:'', title:'', source:'', images:[]};
  if (window.__dyCapture) {
    out.video = window.__dyCapture.video || '';
    out.cover = window.__dyCapture.cover || '';
    out.title = window.__dyCapture.title || '';
    out.source = window.__dyCapture.source || '';
    if (window.__dyCapture.images && window.__dyCapture.images.length) {
      out.images = window.__dyCapture.images.slice();
    }
  }

  if (!okVideo(out.video)) {
    out.video = '';
    try {
      var entries = performance.getEntriesByType('resource');
      var best = '';
      var bestScore = -1;
      for (var i = 0; i < entries.length; i++) {
        var n = entries[i].name || '';
        if (!okVideo(n)) continue;
        var sc = scoreUrl(n);
        if (n.indexOf('photo-video') >= 0) sc += 8;
        if (n.indexOf('media-video') >= 0) sc += 4;
        if (sc > bestScore) {
          bestScore = sc;
          best = n;
        }
      }
      if (best) {
        out.video = best;
        out.source = out.source || 'resource';
      }
    } catch (e) {}
  }

  if (!out.cover) {
    try {
      var metas = document.querySelectorAll('meta[property="og:image"], meta[name="og:image"]');
      for (var m = 0; m < metas.length; m++) {
        var c = metas[m].getAttribute('content') || '';
        if (c.indexOf('http') === 0) { out.cover = c; break; }
      }
    } catch (e) {}
  }
  if (!out.cover) {
    try {
      var imgs = document.querySelectorAll('img');
      for (var j = 0; j < imgs.length; j++) {
        var s = imgs[j].src || '';
        if (s.indexOf('douyinpic') >= 0) {
          if (s.indexOf('avatar') >= 0 || s.indexOf('100x100') >= 0) continue;
          if (s.indexOf('biz_tag=aweme_comment') >= 0) continue;
          if (s.indexOf('cover') >= 0 || s.indexOf('origin_cover') >= 0 || s.indexOf('tplv') >= 0) {
            out.cover = s;
            break;
          }
        }
        if (s.indexOf('yximgs.com') >= 0 || s.indexOf('kwimgs.com') >= 0) {
          if (s.indexOf('_b_') >= 0 || s.indexOf('uhead') >= 0) continue;
          if (s.indexOf('upic') >= 0 || s.indexOf('clientCacheKey') >= 0) {
            out.cover = s;
            break;
          }
        }
      }
    } catch (e) {}
  }

  if (!out.title) out.title = document.title || '';
  if (!okVideo(out.video)) out.video = '';

  function pushImage(u){
    if (!okImage(u)) return;
    // 去掉签名后比较，避免同图不同 CDN 重复
    var key = u.split('?')[0];
    for (var pi = 0; pi < out.images.length; pi++) {
      if (out.images[pi].split('?')[0] === key) return;
    }
    out.images.push(u);
  }

  // 若已从 detail 接口拿到完整列表，优先保留
  var fromDetail = out.source.indexOf('detail') >= 0 && out.images.length > 0;

  try {
    var domImgs = document.querySelectorAll('img');
    for (var di = 0; di < domImgs.length; di++) {
      pushImage(domImgs[di].src || '');
      var srcset = domImgs[di].currentSrc || '';
      if (srcset) pushImage(srcset);
    }
  } catch (e) {}

  try {
    var resEntries = performance.getEntriesByType('resource');
    for (var ri = 0; ri < resEntries.length; ri++) {
      pushImage(resEntries[ri].name || '');
    }
  } catch (e) {}

  // 尝试点一下轮播下一张，触发懒加载（不阻塞）
  try {
    if (!fromDetail) {
      var next = document.querySelector(
        'button[class*="arrow"], div[class*="arrow-right"], div[class*="swiper-button-next"], [class*="next"]'
      );
      if (next && typeof next.click === 'function') next.click();
    }
  } catch (e) {}

  if (!out.cover && out.images.length) out.cover = out.images[0];
  return JSON.stringify(out);
})();
''';

  /// 图文页：左右滑动轮播，促发更多图片进入资源列表
  static const String noteNudgeJs = r'''
(function(){
  try {
    var root = document.querySelector('#douyin-web-recommend-card-main')
      || document.querySelector('[class*="note"]')
      || document.body;
    var imgs = document.querySelectorAll('img');
    for (var i = 0; i < Math.min(imgs.length, 8); i++) {
      try { imgs[i].scrollIntoView({block:'nearest', inline:'nearest'}); } catch (e) {}
    }
    // 模拟方向键翻图
    ['ArrowRight','ArrowRight','ArrowRight'].forEach(function(k){
      try {
        document.dispatchEvent(new KeyboardEvent('keydown', {key:k, bubbles:true}));
      } catch (e) {}
    });
  } catch (e) {}
})();
''';

  static String? extractShareUrl(String text) {
    return extractDouyinShareUrl(text) ?? extractKuaishouShareUrl(text);
  }

  static String? extractDouyinShareUrl(String text) {
    return _douyinShareUrlRe.firstMatch(text)?.group(0);
  }

  static String? extractKuaishouShareUrl(String text) {
    return _kuaishouShareUrlRe.firstMatch(text)?.group(0);
  }

  static String videoPageUrl(String awemeId) =>
      'https://www.douyin.com/video/$awemeId';

  static String kuaishouVideoPageUrl(String photoId) =>
      'https://www.kuaishou.com/short-video/$photoId';

  /// 快手移动端图文/作品分享页（图集可在此加载 atlas）
  static String kuaishouPhotoPageUrl(String photoId) =>
      'https://v.m.chenzhongtech.com/fw/photo/$photoId';

  static String notePageUrl(String noteId) =>
      'https://www.douyin.com/note/$noteId';

  static bool isDouyinNote(String text) {
    if (_noteIdRe.hasMatch(text)) return true;
    if (text.contains('/share/note/')) return true;
    if (text.contains('schema_type=37')) return true;
    return false;
  }

  static bool isKuaishouAtlasUrl(String url) {
    final u = url.toLowerCase();
    return u.contains('subbiz=browse_slide_photo') ||
        u.contains('shareresourcetype=photo_other') ||
        u.contains('shareresourcetype=photo') ||
        u.contains('browse_slide_photo');
  }

  static bool isDownloadableImageUrl(String url) {
    final u = url.trim();
    if (u.isEmpty || !u.startsWith('http')) return false;
    if (u.contains('avatar') ||
        u.contains('100x100') ||
        u.contains('aweme_comment') ||
        u.contains('sticker') ||
        u.contains('pcweb_cover') ||
        u.contains('noop.jpeg') ||
        u.contains('image-cut-tos') ||
        u.contains('uhead') ||
        u.contains('emotion')) {
      return false;
    }
    // 快手图集
    if (u.contains('/ufile/atlas/')) return true;
    if ((u.contains('yximgs.com') || u.contains('kwimgs.com')) &&
        u.contains('/ufile/') &&
        (u.contains('.jpg') ||
            u.contains('.jpeg') ||
            u.contains('.webp') ||
            u.contains('.png'))) {
      return true;
    }
    if (!u.contains('douyinpic.com')) return false;
    return u.contains('biz_tag=aweme_images') ||
        u.contains('tplv-dy-aweme-images') ||
        u.contains('tos-cn-i-');
  }

  static String refererFor(ShortVideoPlatform platform) =>
      platform == ShortVideoPlatform.kuaishou
          ? 'https://www.kuaishou.com/'
          : 'https://www.douyin.com/';

  static bool isDownloadableVideoUrl(String url) {
    final u = url.trim();
    if (u.isEmpty) return false;
    if (u.startsWith('blob:')) return false;
    if (u.contains('playwm')) return false;
    if (!u.startsWith('http')) return false;
    final hostOk = u.contains('douyinvod.com') ||
        u.contains('bytevod') ||
        u.contains('365yg.com') ||
        u.contains('douyin.com/aweme/v1') ||
        u.contains('kwaicdn.com') ||
        (u.contains('yximgs.com') && u.contains('.mp4')) ||
        (u.contains('kwimgs.com') && u.contains('.mp4')) ||
        u.contains('ndcimgs.com') ||
        u.contains('chenzhongtech.com') ||
        (u.contains('mime_type=video_mp4') && u.contains('/video/')) ||
        (u.contains('.mp4') &&
            (u.contains('photo-video') || u.contains('/upic/')));
    if (!hostOk) return false;
    if (u.contains('media-audio')) return false;
    if (u.contains('.js') && !u.contains('mime_type=video_mp4')) return false;
    return true;
  }

  static Future<String> resolveAwemeId(String input) async {
    final shareUrl = extractDouyinShareUrl(input) ?? input.trim();
    if (shareUrl.isEmpty) {
      throw Exception('未找到抖音分享链接');
    }

    final directId = _awemeIdRe.firstMatch(shareUrl)?.group(1);
    if (directId != null) return directId;

    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 12),
        receiveTimeout: const Duration(seconds: 12),
        followRedirects: false,
        validateStatus: (code) => code != null && code >= 200 && code < 400,
        headers: {
          'User-Agent': userAgent,
          'Accept': 'text/html,application/xhtml+xml,*/*',
        },
      ),
    );

    var current = shareUrl;
    for (var i = 0; i < 8; i++) {
      final id = _awemeIdRe.firstMatch(current)?.group(1);
      if (id != null) return id;

      final response = await dio.get(current);
      final location = response.headers.value('location');
      if (location == null || location.isEmpty) {
        final real = response.realUri.toString();
        final fromReal = _awemeIdRe.firstMatch(real)?.group(1);
        if (fromReal != null) return fromReal;
        break;
      }
      current = Uri.parse(current).resolve(location).toString();
    }

    throw Exception('无法从链接解析视频 ID，请换一条分享链接重试');
  }

  /// 抖音图文：短链 / iesdouyin 分享 → noteId
  static Future<String> resolveNoteId(String input) async {
    final noteUrlRe = RegExp(
      r'https?://(?:www\.)?(?:iesdouyin|douyin)\.com/(?:share/)?note/\d+[^\s]*',
      caseSensitive: false,
    );
    var shareUrl = noteUrlRe.firstMatch(input)?.group(0) ??
        extractDouyinShareUrl(input) ??
        input.trim();
    if (shareUrl.isEmpty) {
      throw Exception('未找到抖音图文链接');
    }

    final directId = _noteIdRe.firstMatch(shareUrl)?.group(1);
    if (directId != null) return directId;

    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 12),
        receiveTimeout: const Duration(seconds: 12),
        followRedirects: false,
        validateStatus: (code) => code != null && code >= 200 && code < 400,
        headers: {
          'User-Agent': userAgent,
          'Accept': 'text/html,application/xhtml+xml,*/*',
        },
      ),
    );

    var current = shareUrl;
    for (var i = 0; i < 8; i++) {
      final id = _noteIdRe.firstMatch(current)?.group(1);
      if (id != null) return id;

      final response = await dio.get(current);
      final location = response.headers.value('location');
      if (location == null || location.isEmpty) {
        final real = response.realUri.toString();
        final fromReal = _noteIdRe.firstMatch(real)?.group(1);
        if (fromReal != null) return fromReal;
        break;
      }
      current = Uri.parse(current).resolve(location).toString();
    }

    throw Exception('无法从链接解析图文 ID，请换一条分享链接重试');
  }

  /// 快手：短链跟跳 → photoId + 是否图集
  static Future<KuaishouResolveMeta> resolveKuaishouMeta(String input) async {
    final shareUrl = extractKuaishouShareUrl(input);
    if (shareUrl == null) {
      throw Exception('未找到快手分享链接');
    }

    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 20),
        followRedirects: true,
        maxRedirects: 8,
        headers: {
          'User-Agent': mobileUserAgent,
          'Accept': 'text/html,application/xhtml+xml,*/*',
          'Referer': 'https://www.kuaishou.com/',
        },
        responseType: ResponseType.plain,
        validateStatus: (code) => code != null && code >= 200 && code < 400,
      ),
    );

    final response = await dio.get<String>(shareUrl);
    final html = response.data ?? '';
    final finalUrl = response.realUri.toString();
    final photoId = _photoIdRe.firstMatch(finalUrl)?.group(1) ??
        _photoIdRe.firstMatch(shareUrl)?.group(1) ??
        _photoIdRe.firstMatch(html)?.group(1);
    if (photoId == null || photoId.isEmpty) {
      throw Exception('无法从链接解析快手作品 ID，请换一条分享链接重试');
    }

    final isAtlas = isKuaishouAtlasUrl(finalUrl) ||
        html.contains('/ufile/atlas/') ||
        html.toLowerCase().contains('browse_slide_photo') ||
        (input.contains('图文') && !html.contains('.mp4'));
    _log(
      'kuaishou meta id=$photoId atlas=$isAtlas '
      'final=${finalUrl.substring(0, finalUrl.length.clamp(0, 120))}',
    );
    return KuaishouResolveMeta(
      photoId: photoId,
      finalUrl: finalUrl,
      isAtlas: isAtlas,
    );
  }

  /// 快手：短链跟跳 → photoId
  static Future<String> resolveKuaishouPhotoId(String input) async {
    final meta = await resolveKuaishouMeta(input);
    return meta.photoId;
  }

  /// 按序号排序图集 URL（…_0.jpg, …_1.jpg）
  static List<String> sortKuaishouAtlasUrls(Iterable<String> urls) {
    final list = urls.toList();
    int indexOf(String u) {
      final m = RegExp(r'_(\d+)\.(?:jpg|jpeg|png|webp)', caseSensitive: false)
          .firstMatch(u.split('?').first);
      return m != null ? int.tryParse(m.group(1)!) ?? 9999 : 9999;
    }

    list.sort((a, b) => indexOf(a).compareTo(indexOf(b)));
    return list;
  }

  /// 快手：尝试 HTTP 直解析（新版分享页常为空，失败时由 WebView 兜底）
  static Future<DouyinResolveResult?> tryResolveKuaishouHttp(String input) async {
    final shareUrl = extractKuaishouShareUrl(input);
    if (shareUrl == null) return null;
    _log('kuaishou http shareUrl=$shareUrl');

    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 20),
        followRedirects: true,
        maxRedirects: 8,
        headers: {
          'User-Agent': mobileUserAgent,
          'Accept': 'text/html,application/xhtml+xml,*/*',
          'Referer': 'https://www.kuaishou.com/',
        },
        responseType: ResponseType.plain,
        validateStatus: (code) => code != null && code >= 200 && code < 400,
      ),
    );

    final response = await dio.get<String>(shareUrl);
    final html = response.data ?? '';
    final finalUrl = response.realUri.toString();
    _log('kuaishou http final=$finalUrl htmlLen=${html.length}');

    final photoId = _photoIdRe.firstMatch(finalUrl)?.group(1) ??
        _photoIdRe.firstMatch(html)?.group(1) ??
        '';

    // 图集：HTML / 跳转参数里可能直接带 atlas 图
    final atlasFromHtml = RegExp(
      r'https://[^"\\\s<>]+/ufile/atlas/[^"\\\s<>]+',
      caseSensitive: false,
    ).allMatches(html).map((m) => m.group(0)!).where(isDownloadableImageUrl);
    final atlasUrls = sortKuaishouAtlasUrls({...atlasFromHtml});
    if (atlasUrls.isNotEmpty || isKuaishouAtlasUrl(finalUrl)) {
      if (atlasUrls.isNotEmpty) {
        final title = _pickJsonString(html, const [
              'caption',
              'shareTitle',
              'photoDescription',
              'title',
            ]) ??
            '';
        _log('kuaishou http atlas id=$photoId count=${atlasUrls.length}');
        return DouyinResolveResult(
          awemeId: photoId.isNotEmpty ? photoId : 'kuaishou',
          videoUrl: '',
          title: title,
          coverUrl: atlasUrls.first,
          source: 'kuaishou/http',
          platform: ShortVideoPlatform.kuaishou,
          mediaType: DouyinMediaType.images,
          imageUrls: atlasUrls,
        );
      }
      // 识别为图集但 HTML 无图：交给 WebView
      return null;
    }

    final initMatch = RegExp(
      r'window\.INIT_STATE\s*=\s*(\{[\s\S]*?\})\s*;?\s*</script>',
    ).firstMatch(html);
    if (initMatch == null) return null;

    Map<String, dynamic> initJson;
    try {
      initJson = jsonDecode(initMatch.group(1)!) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
    if (initJson.isEmpty) return null;

    final blob = jsonEncode(initJson);
    final title = _pickJsonString(blob, const [
          'caption',
          'shareTitle',
          'photoDescription',
          'title',
        ]) ??
        '';

    final mp4Urls = RegExp(r'https://[^"\\]+\.mp4[^"\\]*')
        .allMatches(blob)
        .map((m) => m.group(0)!)
        .toSet()
        .toList();
    if (mp4Urls.isEmpty) return null;

    final videoUrl = _pickBestKuaishouUrl(mp4Urls);
    if (videoUrl == null || !isDownloadableVideoUrl(videoUrl)) return null;

    String? cover;
    final coverMatches = RegExp(
      r'https://[^"\\]+\.(?:jpg|jpeg|png|webp)[^"\\]*',
      caseSensitive: false,
    ).allMatches(blob).map((m) => m.group(0)!);
    for (final c in coverMatches) {
      if (c.contains('emotion') || c.contains('uhead')) continue;
      if (c.contains('upic') ||
          c.contains('clientCacheKey') ||
          c.contains('heif') ||
          c.contains('jpg')) {
        cover = c;
        break;
      }
    }

    _log(
      'kuaishou http ok id=$photoId '
      'video=${videoUrl.substring(0, videoUrl.length.clamp(0, 80))}...',
    );
    return DouyinResolveResult(
      awemeId: photoId.isNotEmpty ? photoId : 'kuaishou',
      videoUrl: videoUrl,
      title: title,
      coverUrl: cover,
      source: 'kuaishou/http',
      platform: ShortVideoPlatform.kuaishou,
    );
  }

  static String? _pickJsonString(String blob, List<String> keys) {
    for (final key in keys) {
      final m = RegExp('"$key"\\s*:\\s*"([^"]{1,300})"').firstMatch(blob);
      if (m != null) {
        final v = m.group(1)!.trim();
        if (v.isNotEmpty && v != '去快手享超清画质') return v;
      }
    }
    return null;
  }

  /// 优先 photo-video-mz / hd；避开带 _b_ 的疑似水印流
  static String? _pickBestKuaishouUrl(List<String> urls) {
    int score(String u) {
      var s = 0;
      if (u.contains('photo-video-mz')) s += 50;
      if (u.contains('hd15') || u.contains('tt=hd')) s += 20;
      if (u.contains('_b_') || u.contains('tt=b') || u.contains('_b.mp4')) {
        s -= 40;
      }
      if (u.contains('kwaicdn.com')) s += 5;
      if (u.contains('watermark')) s -= 100;
      return s;
    }

    urls.sort((a, b) => score(b).compareTo(score(a)));
    return urls.isEmpty ? null : urls.first;
  }

  /// 可选：yt-dlp + 浏览器 Cookie。失败返回 null，不抛错。
  static Future<DouyinResolveResult?> tryResolveWithYtDlp(String input) async {
    final shareUrl = extractDouyinShareUrl(input);
    if (shareUrl == null) return null;
    return _resolveWithYtDlp(shareUrl);
  }

  static Future<String?> _findYtDlp() async {
    final candidates = <String>[
      'yt-dlp',
      '${Platform.environment['HOME']}/Library/Python/3.9/bin/yt-dlp',
      '${Platform.environment['HOME']}/Library/Python/3.10/bin/yt-dlp',
      '${Platform.environment['HOME']}/Library/Python/3.11/bin/yt-dlp',
      '${Platform.environment['HOME']}/Library/Python/3.12/bin/yt-dlp',
      '/opt/homebrew/bin/yt-dlp',
      '/usr/local/bin/yt-dlp',
    ];
    for (final c in candidates) {
      try {
        final r = await Process.run(c, ['--version']);
        if (r.exitCode == 0) {
          _log('yt-dlp=$c ${(r.stdout as String).trim()}');
          return c;
        }
      } catch (_) {}
    }
    try {
      final r = await Process.run('python3', ['-m', 'yt_dlp', '--version']);
      if (r.exitCode == 0) {
        _log('yt-dlp=python3 -m yt_dlp');
        return 'python3 -m yt_dlp';
      }
    } catch (_) {}
    return null;
  }

  static Future<DouyinResolveResult?> _resolveWithYtDlp(String shareUrl) async {
    final bin = await _findYtDlp();
    if (bin == null) {
      _log('未找到 yt-dlp，跳过');
      return null;
    }

    final cookieModes = <String?>[null, 'chrome', 'safari', 'edge'];

    for (final browser in cookieModes) {
      try {
        final useModule = bin.startsWith('python3');
        final executable = useModule ? 'python3' : bin;
        final args = <String>[
          if (useModule) ...['-m', 'yt_dlp'],
          '--no-warnings',
          if (browser != null) ...['--cookies-from-browser', browser],
          '-j',
          shareUrl,
        ];
        _log(browser == null
            ? '尝试 yt-dlp（无 Cookie）'
            : '尝试 yt-dlp cookies=$browser');
        final result = await Process.run(
          executable,
          args,
          runInShell: false,
        ).timeout(const Duration(seconds: 35));

        if (result.exitCode != 0) {
          _log('yt-dlp(${browser ?? 'none'}) fail: ${'${result.stderr}'.trim()}');
          continue;
        }

        final stdout = '${result.stdout}'.trim();
        final start = stdout.indexOf('{');
        if (start < 0) continue;
        final map = jsonDecode(stdout.substring(start)) as Map<String, dynamic>;
        final id = '${map['id'] ?? ''}';
        final title = '${map['title'] ?? ''}';
        final thumb = '${map['thumbnail'] ?? ''}';
        var url = '${map['url'] ?? ''}';
        if (!isDownloadableVideoUrl(url)) {
          url = _pickBestFormatUrl(map) ?? url;
        }
        if (!isDownloadableVideoUrl(url)) continue;

        final source = browser == null ? 'yt-dlp' : 'yt-dlp/$browser';
        _log('成功 source=$source id=$id');
        return DouyinResolveResult(
          awemeId: id.isNotEmpty ? id : (await resolveAwemeId(shareUrl)),
          videoUrl: url,
          title: title,
          coverUrl: thumb.isNotEmpty ? thumb : null,
          source: source,
          platform: ShortVideoPlatform.douyin,
        );
      } catch (e) {
        _log('yt-dlp(${browser ?? 'none'}) exception: $e');
      }
    }
    return null;
  }

  static String? _pickBestFormatUrl(Map<String, dynamic> map) {
    final formats = map['formats'];
    if (formats is! List) return null;
    String? best;
    var bestScore = -1;
    for (final item in formats) {
      if (item is! Map) continue;
      final url = '${item['url'] ?? ''}';
      if (!isDownloadableVideoUrl(url)) continue;
      final ext = '${item['ext'] ?? ''}';
      final vcodec = '${item['vcodec'] ?? ''}';
      final acodec = '${item['acodec'] ?? ''}';
      var score = 0;
      if (ext == 'mp4') score += 5;
      if (vcodec != 'none' && vcodec.isNotEmpty) score += 3;
      if (acodec != 'none' && acodec.isNotEmpty) score += 4;
      if (url.contains('watermark=0') || url.contains('unwatermarked')) {
        score += 30;
      }
      if (url.contains('playwm')) score -= 100;
      final h = item['height'];
      if (h is num) score += (h ~/ 100);
      if (score > bestScore) {
        bestScore = score;
        best = url;
      }
    }
    return best;
  }

  static Map<String, dynamic>? decodeJsJson(Object? raw) {
    if (raw == null) return null;
    var text = raw.toString().trim();
    if (text.length >= 2 && text.startsWith('"') && text.endsWith('"')) {
      try {
        text = jsonDecode(text) as String;
      } catch (_) {}
    }
    text = text.replaceAll(r'\"', '"');
    try {
      final decoded = jsonDecode(text);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
    return null;
  }

  static Future<void> downloadWithReferer({
    required String url,
    required String savePath,
    void Function(int received, int total)? onProgress,
  }) async {
    if (!isDownloadableVideoUrl(url) && !_looksLikeImage(url)) {
      throw Exception('无效的下载地址（拒绝 blob / 脚本等伪链接）');
    }

    final isKs = url.contains('kwaicdn') ||
        url.contains('yximgs') ||
        url.contains('kwimgs') ||
        url.contains('ndcimgs');

    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(minutes: 5),
        followRedirects: true,
        headers: {
          'User-Agent': isKs ? mobileUserAgent : userAgent,
          'Referer':
              isKs ? 'https://www.kuaishou.com/' : 'https://www.douyin.com/',
          'Accept': '*/*',
        },
      ),
    );
    final response = await dio.download(
      url,
      savePath,
      onReceiveProgress: onProgress,
    );
    final code = response.statusCode ?? 0;
    if (code < 200 || code >= 300) {
      throw Exception('下载失败，HTTP $code');
    }
  }

  static bool _looksLikeImage(String url) {
    final u = url.toLowerCase();
    return u.contains('douyinpic.com') ||
        u.contains('yximgs.com') ||
        u.contains('kwimgs.com') ||
        u.contains('.jpeg') ||
        u.contains('.jpg') ||
        u.contains('.png') ||
        u.contains('tplv-');
  }

  static Future<void> assertValidMp4(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      throw Exception('文件不存在');
    }
    final size = await file.length();
    if (size < 8 * 1024) {
      throw Exception('文件过小（${size}B），不是有效视频');
    }
    final head = await file.openRead(0, 64).fold<List<int>>(
      <int>[],
      (prev, chunk) => prev..addAll(chunk),
    );
    final isMp4 = head.length >= 8 &&
        String.fromCharCodes(head.sublist(4, 8)) == 'ftyp';
    if (!isMp4) {
      final text = String.fromCharCodes(head.take(40));
      throw Exception('下载结果不是 MP4（文件头: $text…），请重新解析');
    }
  }
}
