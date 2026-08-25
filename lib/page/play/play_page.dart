import 'package:adb_player/dialog/music_player_dialog.dart';
import 'package:adb_player/dialog/smart_dialog_utils.dart';
import 'package:adb_player/page/play/code_rain_page.dart';
import 'package:adb_player/page/play/liang_calibrator_page.dart';
import 'package:adb_player/page/play/short_video_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdfx/pdfx.dart';

/// 赏心悦目 —— 全屏 PageView 上下滑动播放
const List<String> _shortVideoUrls = [
  'https://v9-dy.ixigua.com/52cadc2f593b28adf7fbe060992ea6ac/6a8309ae/video/tos/cn/tos-cn-ve-15/oMBbfAEMUC4mm3lXQQetzAAOBBQe8nvAp7iO05/?a=1768&ch=0&cr=0&dr=0&er=0&lr=unwatermarked&net=5&cd=0%7C0%7C0%7C0&cv=1&br=1670&bt=1670&cs=0&ds=4&ft=ahW46QQqUuIf_oZmo0OW_QYaUqiX5A.y9VJEtyYvVbPD-Ipz&mime_type=video_mp4&qs=0&rc=aWY2ZTw0NWVkZTY1ZWQ3M0BpM2Y7d3Y5cnlwPDMzNGkzM0BfX19fL14tXi8xM2AtMGJiYSNsNjZsMmQ0ajRhLS1kLS9zcw%3D%3D&btag=80000e00008000&dy_q=1786968980&feature_id=37f92ebd2877ae8e7eba995d406c5150&l=20260817201620F3C585C94D8A4D0EA013&playAddrKey=v0200fg10000d97mmv7og65sot989co0',
  'https://v9-dy.ixigua.com/eb229a3773ef0c541f59483c6bda608f/6a830acd/video/tos/cn/tos-cn-ve-15/osrUPf2Iaf7wLEHIrCLUAa1GAnaIvB0yeMqB9c/?a=1768&ch=0&cr=0&dr=0&er=0&lr=unwatermarked&net=5&cd=0%7C0%7C0%7C0&cv=1&br=977&bt=977&cs=0&ds=4&ft=ahW46QQqUuIf_oZmo0OW_QYaUqiXBv.y9VJEtyYvVbPD-Ipz&mime_type=video_mp4&qs=0&rc=N2U6NzU7O2k2OGc6OzU2OUBpamU2eXE5cms5PDMzNGkzM0AyMF4uYTA0Nl4xXmE1YTBhYSNnb3I0MmRzYV5hLS1kLWFzcw%3D%3D&btag=80000e00008000&dy_q=1786969271&feature_id=37f92ebd2877ae8e7eba995d406c5150&l=20260817202111D0FD0EC05BCA1E07D028&playAddrKey=v0d00fg10000d9a6dhvog65n7vu3rbjg',
  'https://v9-dy.ixigua.com/5e77a4bbbaccbabad5e9913d43fb549f/6a830b88/video/tos/cn/tos-cn-ve-15c000-ce/ogLAKBiasSBBeGwiEQLGiCbEf8oQF1EAToIVgm/?a=1768&ch=0&cr=0&dr=0&er=0&lr=unwatermarked&net=5&cd=0%7C0%7C0%7C0&cv=1&br=1406&bt=1406&cs=0&ds=4&ft=ahW46QQqUuIf_oZmo0OW_QYaUqiXNf.y9VJEn_dWcbPD-Ipz&mime_type=video_mp4&qs=0&rc=MzY0ZDhkaWg1NjZnODlpaEBpMzUzO3Y5cmRuPDMzbGkzNUAzYjFiYTU1NjMxYC02Ly0xYSMyYTI1MmRzMWFhLS1kLTVzcw%3D%3D&btag=80000e00008000&dy_q=1786969458&feature_id=37f92ebd2877ae8e7eba995d406c5150&l=20260817202418871A2F58DE67C4099743&playAddrKey=v2800fgi0000d9dk4avog65s8850d250',
  'https://v9-dy.ixigua.com/0a3a39130d9583da5b373f6d6734c436/6a830b9e/video/tos/cn/tos-cn-ve-15c000-ce/o0vwBiNAiElIwlORt1fnHDtAeNbU1BoMEQOsBo/?a=1768&ch=0&cr=0&dr=0&er=0&lr=unwatermarked&net=5&cd=0%7C0%7C0%7C0&cv=1&br=2314&bt=2314&cs=0&ds=4&ft=ahW46QQqUuIf_oZmo0OW_QYaUqiXxu.y9VJEtyYvVbPD-Ipz&mime_type=video_mp4&qs=0&rc=M2ZmODdlOmRkPGZpOmk4O0BpajRrcGo5cnB1PDMzbGkzNUAwXjMuLjEuXl8xXmFfNmMxYSMwL20zMmRzNG5hLS1kLTVzcw%3D%3D&btag=80000e00008000&dy_q=1786969475&feature_id=37f92ebd2877ae8e7eba995d406c5150&l=2026081720243542EF7831E1B0A82D00A8&playAddrKey=v2800fgi0000d9qr7mvog65g6mph213g',
  'https://v5-dy.ixigua.com/1135df3d9b2e68c29c1130aaa9fa4809/6a830c87/video/tos/cn/tos-cn-ve-15/oEfqHX9GAwBgCBUilUiePIEdAlCIEgB9UnQDkA/?a=0&ch=0&cr=0&dr=0&lr=normal&net=5&cd=0%7C0%7C0%7C0&cv=1&br=1958&bt=1958&cs=0&ds=4&ft=k7Fz7VVywIiRZm8Zmo~pK7pswApfGsBVvrKlISd2do0g3cI&mime_type=video_mp4&qs=0&rc=MzdmOGU1OzVoOjdnO2lnM0Bpajo8NXc5cjpuZDMzNGkzM0AvMTQyNi5hXzQxMGIvLmE2YSNmYy1mMmRzci1hLS1kLTBzcw%3D%3D&btag=80000e00008000&cquery=106H&dy_q=1786969711&feature_id=37f92ebd2877ae8e7eba995d406c5150&l=20260817202831516C3E63651B72494C0C',
  'https://v11-default.365yg.com/eaeac256a229b67b25bb00a33f59d363/6a830d0b/video/tos/cn/tos-cn-ve-15c000-ce/ooJNaQnB1Bn8OgCiiDTPKAI9AEw6fPPwheEkJ0/?a=0&ch=0&cr=0&dr=0&lr=normal&net=5&cd=0%7C0%7C0%7C0&cv=1&br=2117&bt=2117&cs=0&ds=4&ft=k7Fz7VVywIiRZm8Zmo~pK7pswApf8sBVvrKoav_jto0g3cI&mime_type=video_mp4&qs=0&rc=OWc7OTc0ZzplPDY1Zmk0Z0BpamgzcnY5cnR4PDMzbGkzNUAuYDMxYy1eNl4xLWBfYC0wYSMxMWJyMmRjYXBhLS1kLTRzcw%3D%3D&btag=80000e00008000&cquery=106H&dy_q=1786969839&feature_id=37f92ebd2877ae8e7eba995d406c5150&l=20260817203039FCB9B2499AA95F14751B',
  'https://v9-dy.ixigua.com/120e93f1a9cd8462b21c49e759ffcf44/6a830cf9/video/tos/cn/tos-cn-ve-15/oo4cAoMEzL9wQE6IIBFqAoRDgfDLDA0UfJXAMo/?a=1768&ch=0&cr=0&dr=0&er=0&lr=unwatermarked&net=5&cd=0%7C0%7C0%7C0&cv=1&br=3277&bt=3277&cs=0&ds=4&ft=ahW46QQqUuIf_oZmo0OW_QYaUqiX6m.y9VJEn_dWcbPD-Ipz&mime_type=video_mp4&qs=0&rc=aGc4OTY0ZGVpNmhmZzpoM0BpanYzNG45cjM8PDMzNGkzM0AwMDUvNDNhXzYxNV5jYGJiYSNjYGNeMmQ0M2JhLS1kLTBzcw%3D%3D&btag=80000e00008000&dy_q=1786969824&feature_id=37f92ebd2877ae8e7eba995d406c5150&l=202608172030240BF35862BABD7C13E501&playAddrKey=v0300fg10000d9e9607og65ka1f0csfg',
  'https://v9-dy.ixigua.com/9017b16a44f08e0136d6cb7317d3e9cc/6a830d16/video/tos/cn/tos-cn-ve-15c000-ce/ocAggLvTA4dkG0RD7e5CK9Bfg8ITJzXIvUfQQM/?a=1768&ch=0&cr=0&dr=0&er=0&lr=unwatermarked&net=5&cd=0%7C0%7C0%7C0&cv=1&br=1380&bt=1380&cs=0&ds=4&ft=ahW46QQqUnXfmoZmo0OW_QYaUqiX~m.y9VJE27ExrCPD-Ipz&mime_type=video_mp4&qs=0&rc=aDdlPDY1NTppZWY2ZzU3ZkBpM3E0aXk5cjU4PDMzbGkzNEAvXl9gYjU2XzIxLy8tMV4wYSNnYzJrMmRjLWxhLS1kLWJzcw%3D%3D&btag=80000e00008000&dy_q=1786969853&feature_id=37f92ebd2877ae8e7eba995d406c5150&l=2026081720305326FF272DB66FD10AE496&playAddrKey=v1e00fgi0000d9o502fog65vnf51fnj0',
  'https://v5-se-jltc-default.365yg.com/5edf52fa6265898f883a20a42e600120/6a830d27/video/tos/cn/tos-cn-ve-15c000-ce/oA29iXEKxI1Tifo8AICcMbwQDfADFEgrBB2qzI/?a=0&ch=0&cr=0&dr=0&lr=normal&net=5&cd=0%7C0%7C0%7C0&cv=1&br=3484&bt=3484&cs=0&ds=4&ft=k7Fz7VVywIiRZm8Zmo~pK7pswApRvsBVvrKQeooNdo0g3cI&mime_type=video_mp4&qs=0&rc=O2Y5Z2ZlMzc3aTpmNmY8O0Bpam81PGs5cjptPDMzbGkzNUAxMy40Yl5jX2ExNS1jMy4vYSNxLjBhMmQ0LmNhLS1kLTVzcw%3D%3D&btag=80000e00008000&cquery=106H&dy_q=1786969869&feature_id=37f92ebd2877ae8e7eba995d406c5150&l=20260817203109C99339BFCB85EC180858',
  'https://v3-dy.ixigua.com/71287d979eb0c1b631ce39322a09ad9c/6a830d38/video/tos/cn/tos-cn-ve-15/oMeRARng6efrCGpQ1tNPD4gLOYoe41AV2AELbI/?a=1768&ch=0&cr=0&dr=0&er=0&lr=unwatermarked&net=5&cd=0%7C0%7C0%7C0&cv=1&br=2723&bt=2723&cs=0&ds=4&ft=ahW46QQqUuIf_oZmo0OW_QYaUqiXlV.y9VJEtyYvVbPD-Ipz&mime_type=video_mp4&qs=0&rc=Zjc5PDYzaTRmPDhnNmU0aUBpMzh5dHA5cmZtPDMzNGkzM0AxYWA1MDBeNi8xMjBfMWEzYSNeY25lMmRzNmdhLS1kLS9zcw%3D%3D&btag=80000e00008000&dy_q=1786969887&feature_id=37f92ebd2877ae8e7eba995d406c5150&l=2026081720312794FEE427518D8921C211&playAddrKey=v0200fg10000d9jj9cvog65mhqqvf5a0',
  'https://v11-default.365yg.com/1af3f0103778df986f464e965767a601/6a830d50/video/tos/cn/tos-cn-ve-15c000-ce/ogAAxLqnsu51Gf9H7eHDOfB3gOImJVbR9UgWgM/?a=0&ch=0&cr=0&dr=0&lr=normal&net=5&cd=0%7C0%7C0%7C0&cv=1&br=1683&bt=1683&cs=0&ds=4&ft=k7Fz7VVywIiRZm8Zmo~pK7pswAp7vsBVvrKoav_jto0g3cI&mime_type=video_mp4&qs=0&rc=ZmY1OGkzOzg6Zjc2OjlmNkBpamlwN3c5cjc6PDMzbGkzNUAuYjJiMl4xNjIxXjUyNTE2YSM2aWJzMmRzX2JhLS1kLTRzcw%3D%3D&btag=80000e00008000&cquery=106H&dy_q=1786969912&feature_id=37f92ebd2877ae8e7eba995d406c5150&l=202608172031528DE0D2DF298468120D10',
  'https://v11-default.365yg.com/59ded77e19f1fb02b0a38dc181a983a0/6a830f2d/video/tos/cn/tos-cn-ve-15c000-ce/okBaSBBPSvLIWZjIiQiiGBCakFE6vRkAmAMxE/?a=0&ch=0&cr=0&dr=0&lr=normal&net=5&cd=0%7C0%7C0%7C0&cv=1&br=816&bt=816&cs=0&ds=4&ft=k7Fz7VVywIiRZm8Zmo~pK7pswApXIOBVvrKoav_jto0g3cI&mime_type=video_mp4&qs=0&rc=aTplNjkzaDo2NTk5ZzRoZEBpM2xydnQ5cnMzPDMzbGkzNUAuNC9hL2MxX2AxNjFeX14vYSNnXjU1MmRrai5hLS1kLTVzcw%3D%3D&btag=80000e00010000&cquery=106H&dy_q=1786970382&feature_id=37f92ebd2877ae8e7eba995d406c5150&l=20260817203942172F5E46E158052366B2',
  'https://v9-dy.ixigua.com/753621503981df618b147025dad5f21b/6a830d77/video/tos/cn/tos-cn-ve-15c000-ce/oIf9oSEdLBXKhLnHARXSnBwIDfAXFEQviB2q5E/?a=1768&br=1770&bt=1770&btag=80000e00008000&cd=0%7C0%7C0%7C0&ch=0&cr=0&cs=0&cv=1&dr=0&ds=4&dy_q=1786969951&dy_va_biz_cert=&er=0&feature_id=37f92ebd2877ae8e7eba995d406c5150&ft=ahW46QQqUnXfmoZmo0OW_QYaUqiXlO.y9VJE27ExrCPD-Ipz&l=20260817203231854B15285D2A290B038A&lr=unwatermarked&mime_type=video_mp4&net=5&qs=0&rc=NGhmZ2doaTY8ZzNkN2YzZ0BpanFxdG45cm5zPDMzbGkzNUAtYV4wL2EzNTAxXy0yXl8tYSNzLzEyMmRrXzJhLS1kLTRzcw%3D%3D&playAddrKey=v2700fgi0000d95pbknog65k5q4n2nvg',
  'https://v9-dy.ixigua.com/86783fbc15442115b217ae6f65e72e07/6a830f55/video/tos/cn/tos-cn-ve-15c000-ce/oYufkTARIrGAfcfL8WG7To01JPMT2DAwgOoGe6/?a=1768&ch=0&cr=0&dr=0&er=0&lr=unwatermarked&net=5&cd=0%7C0%7C0%7C0&cv=1&br=5042&bt=5042&cs=0&ds=4&ft=ahW46QQqUuIf_oZmo0OW_QYaUqiXTzSy9VJEtyYvVbPD-Ipz&mime_type=video_mp4&qs=0&rc=ZDY0ZTU0ZGQzO2g8O2lpZEBpajRtbWw5cmd4OzMzbGkzNUA2NGAvX2IwXl4xNTNgLzEvYSNocWo2MmRjYXNhLS1kLTRzcw%3D%3D&btag=80000e00008000&dy_q=1786970431&feature_id=37f92ebd2877ae8e7eba995d406c5150&l=20260817204031894773D389BE2335A7E7&playAddrKey=v2700fgi0000d8vuddfog65i9jmjt1kg',
];

/// 风景视频 —— 复用短视频播放器
const List<String> _landscapeVideoUrls = [
  'https://v9-dy.ixigua.com/5c15f5e0c68b10a267d5a0c19ff38d5c/6a7f2597/video/tos/cn/tos-cn-ve-15c000-ce/os7EYJgeAxOElQDSheOFELrbIDFf6Gs4vgDCBu/?a=1768&ch=0&cr=0&dr=0&er=0&lr=unwatermarked&net=5&cd=0%7C0%7C0%7C0&cv=1&br=6422&bt=6422&cs=0&ds=4&ft=ahW46QQqUnXfmoZmo0OW_QYaUqiXE7lp9VJE27ExrCPD-Ipz&mime_type=video_mp4&qs=0&rc=NGg0Zmg1ZWc4Zjs4Nmc4ZkBpajh0anI5cnJ4NzMzbGkzNUAzNTQ1Yy1jNi0xYjZjYS5gYSNka2tvMmQ0Mm9hLS1kLTRzcw%3D%3D&btag=80000e00008000&dy_q=1786713984&feature_id=0ea98fd3bdc3c6c14a3d0804cc272721&l=2026081421262441DC79BD37D008A4F3F5&playAddrKey=v2700fgi0000d4ru5o7og65orgnqn5gg',
  'https://v9-dy.ixigua.com/72b676d179b724a3ea5345b3f1b4ce33/6a7f267d/video/tos/cn/tos-cn-ve-15-alinc2/ade912b66e0148b89d7c97bc2aa93704/?a=1768&ch=0&cr=0&dr=0&er=0&lr=unwatermarked&net=5&cd=0%7C0%7C0%7C0&cv=1&br=6446&bt=6446&cs=0&ds=4&ft=ahW46QQqUuIf_oZmo0OW_QYaUqiXQ0lp9VJEtyYvVbPD-Ipz&mime_type=video_mp4&qs=0&rc=N2U6NWk1ZTNpaDhmZmk3OEBpam85Ozs6Zm84OjMzNGkzM0A2XzRgNC9jNTAxLy0zMTAwYSNycmIvcjRvczZgLS1kLS9zcw%3D%3D&btag=80000e00008000&dy_q=1786714214&l=2026081421301430A7317A75DEDD945989&playAddrKey=v0200fg10000c795vlrc77u828e6ulug',
  'https://v9-dy.ixigua.com/ce82283ad642a8e39e244b05db233c58/6a7f26aa/video/tos/cn/tos-cn-ve-15c000-ce/oUe1CQ3DiswiKIFAuwBIBnnKe3JCBEQ9APTEve/?a=1768&ch=0&cr=0&dr=0&er=0&lr=unwatermarked&net=5&cd=0%7C0%7C0%7C0&cv=1&br=2570&bt=2570&cs=0&ds=4&ft=ahW46QQqUuIf_oZmo0OW_QYaUqiXC_lp9VJEtyYvVbPD-Ipz&mime_type=video_mp4&qs=0&rc=OjVlZGg7Nzo5ZmU2OTMzO0Bpamk7bHc5cmZ1OzMzbGkzNEAzLS1hYTUwXi8xXzYuNWFfYSNnaTVnMmQ0YzRhLS1kLWJzcw%3D%3D&btag=80000e00008000&dy_q=1786714256&feature_id=37f92ebd2877ae8e7eba995d406c5150&l=20260814213056B63CA176A8B85EBF4520&playAddrKey=v1e00fgi0000d87rfc7og65tji88lfjg',
  'https://v5-se-jltc-default.365yg.com/149f2c88dac67b22618128c1f975c6ee/6a8307a2/video/tos/cn/tos-cn-ve-15/o02UuXO0DAU7g7ITAQFsfHGDFfLJ4kqEBBCzfI/?a=0&ch=0&cr=0&dr=0&lr=normal&net=5&cd=0%7C0%7C0%7C0&cv=1&br=1716&bt=1716&cs=0&ds=4&ft=k7Fz7VVywIiRZm8Zmo~pK7pswApkVsBVvrKQeooNdo0g3cI&mime_type=video_mp4&qs=0&rc=PDM3Zzg7PDw7N2dnOmQ3ZUBpMzc8a3c5cjRkPDMzNGkzM0A2NmMwNmMzNTMxNWMwLWMwYSNvbGNxMmRjNHNhLS1kLTBzcw%3D%3D&btag=80000e00008000&cquery=106H&dy_q=1786968459&feature_id=37f92ebd2877ae8e7eba995d406c5150&l=202608172007391FF3D514E959AC0D2AD9',
  'https://v9-dy.ixigua.com/24476dfa45dbc8f32585a579e9a1b9bd/6a83086a/video/tos/cn/tos-cn-ve-15c000-ce/owgxfEf2eQI3DtyTIpLABbGFLTegAG8FbI88iH/?a=1768&ch=0&cr=0&dr=0&er=0&lr=unwatermarked&net=5&cd=0%7C0%7C0%7C0&cv=1&br=2336&bt=2336&cs=0&ds=3&ft=ahW46QQqUuIf_oZmo0OW_QYaUqiXYF.y9VJEtyYvVbPD-Ipz&mime_type=video_mp4&qs=0&rc=OmY2NThkOTo3aGhmNzxoaEBpM3lxNms5cnQ4PDMzbGkzNUAuXmJiNjMvXmAxLi41MjY0YSMubDI2MmRjanNhLS1kLTVzcw%3D%3D&btag=40000e00008000&dy_q=1786968657&feature_id=f5241e7604dff1d9d6c943fd20bd51a2&l=202608172010578E67630D7785411EE14B&playAddrKey=v2800fgi0000d9v5mqfog65h935nov10',
  'https://v9-dy.ixigua.com/b228d93fcd745f42a728d4fd9dd02449/6a830892/video/tos/cn/tos-cn-ve-15/ocIJ11cAIBqo7geU24EAdiiA5XBsAOPsOfwPMN/?a=1768&br=1104&bt=1104&btag=40000e00008000&cd=0%7C0%7C0%7C0&ch=0&cr=0&cs=0&cv=1&dr=0&ds=3&dy_q=1786968699&dy_va_biz_cert=&er=0&feature_id=f5241e7604dff1d9d6c943fd20bd51a2&ft=ahW46QQqUuIf_oZmo0OW_QYaUqiXZF.y9VJEn_dWcbPD-Ipz&l=202608172011394F8B5E9AC612C9097801&lr=unwatermarked&mime_type=video_mp4&net=5&qs=0&rc=aGZkOmdoNzllZWVkODU6Z0BpMzM0OHA5cjpvPDMzNGkzM0BhM2AuMjAyNTUxNF41MjRgYSNsbDQ0MmRzbW5hLS1kLWFzcw%3D%3D&playAddrKey=v0d00fg10000d9qlp7vog65m7571o0o0',
  'https://v9-dy.ixigua.com/87125dfeecb520d2236e51e2cd7112e4/6a8308b6/video/tos/cn/tos-cn-ve-15/oIPiXQaj8kXIItUXTkIhgvPMAANuirBjR4Q0E/?a=0&ch=0&cr=0&dr=0&lr=normal&net=5&cd=0%7C0%7C0%7C0&cv=1&br=5409&bt=5409&cs=0&ds=4&ft=k7Fz7VVywIiRZm8Zmo~pK7pswAphNsBVvrK9WB_jto0g3cI&mime_type=video_mp4&qs=0&rc=NTw5ZjY7aWc2NWQ6N2k6PEBpM3Fsb3I5cmVsNjMzNGkzM0BiNS0uM18uXl8xLjFgNWMwYSNecnBqMmQ0NDNhLS1kLS9zcw%3D%3D&btag=80000e00008000&cquery=106H&dy_q=1786968730&feature_id=0ea98fd3bdc3c6c14a3d0804cc272721&l=202608172012102BE0589B0316F42C3EB7',
  'https://v3-dy.ixigua.com/8f13a5c43fb08607e0f11064104975ae/6a8308cb/video/tos/cn/tos-cn-ve-15/oAILp0UAxBJFDgeFxzEA3iiARsBlMdQIxfSIJN/?a=1768&ch=0&cr=0&dr=0&er=0&lr=unwatermarked&net=5&cd=0%7C0%7C0%7C0&cv=1&br=2533&bt=2533&cs=0&ds=4&ft=ahW46QQqUuIf_oZmo0OW_QYaUqiX3j.y9VJEtyYvVbPD-Ipz&mime_type=video_mp4&qs=0&rc=Ojs1OWU8OWVpaTg8ZzY8OkBpM2Zna2s5cjdsNjMzNGkzM0BgMGI0MF8wXmExNGEyXzNgYSM2NWJsMmRjZWhhLS1kLWFzcw%3D%3D&btag=40000e00010000&dy_q=1786968747&feature_id=0ea98fd3bdc3c6c14a3d0804cc272721&l=2026081720122717612E64F9460A0DD35C&playAddrKey=v0d00fg10000d3kih4fog65hohed8c90',
  'https://v6-dy.ixigua.com/1f6711e24c625dbeed3f3daa89faa174/6a8308e3/video/tos/cn/tos-cn-ve-15/owQiTIFIdXAIXB1PiQB7ka2jpqEIW4PPEATRm/?a=0&ch=0&cr=0&dr=0&lr=normal&net=5&cd=0%7C0%7C0%7C0&cv=1&br=4047&bt=4047&cs=0&ds=4&ft=k7Fz7VVywIiRZm8Zmo~pK7pswApggsBVvrKoav_jto0g3cI&mime_type=video_mp4&qs=0&rc=aGU2ZzU6aDw5Ojs3NGlmaEBpajd0b285cjtoODMzNGkzM0BgYmFfLmEyNi8xLzZfLTAzYSMvYW40MmQ0aG5hLS1kLWFzcw%3D%3D&btag=80000e00008000&cquery=106H&dy_q=1786968778&feature_id=0ea98fd3bdc3c6c14a3d0804cc272721&l=202608172012584B73CC721B00A716999A',
  'https://v9-dy.ixigua.com/dce488d98a35feb9274a07a3388bec02/6a8308f9/video/tos/cn/tos-cn-ve-15/oouA93qEasaDKBUVgICTbfETFAA9RQWe3JuiDI/?a=1768&ch=0&cr=0&dr=0&er=0&lr=unwatermarked&net=5&cd=0%7C0%7C0%7C0&cv=1&br=2762&bt=2762&cs=0&ds=4&ft=ahW46QQqUnXfmoZmo0OW_QYaUqiXz-.y9VJE27ExrCPD-Ipz&mime_type=video_mp4&qs=0&rc=ZmhkZzhlNTVkaGc3NDo8ZEBpanRsZXg5cmx1PDMzNGkzM0BiXjMxNDQuXjMxMi1eM2JeYSMxcC9lMmQ0b2BhLS1kLS9zcw%3D%3D&btag=80000e00008000&dy_q=1786968798&feature_id=37f92ebd2877ae8e7eba995d406c5150&l=202608172013184CD34A6E944B1C0015D4&playAddrKey=v0200fg10000d9crri7og65uhb2isq4g',
  'https://v26-dy.ixigua.com/d5dad937645cadcf300cd55b0196141c/6a83091e/video/tos/cn/tos-cn-ve-15c000-ce/oAOW9wkhqQnWArEsBBSFfyFEIdDgHDAxjwfNEE/?a=0&ch=0&cr=0&dr=0&lr=normal&net=5&cd=0%7C0%7C0%7C0&cv=1&br=3385&bt=3385&cs=0&ds=3&ft=k7Fz7VVywIiRZm8Zmo~pK7pswApygsBVvrKlISd2do0g3cI&mime_type=video_mp4&qs=0&rc=Njc6NDdoZzxmOTMzZDhkO0BpMzp1cnA5cnJqPDMzbGkzNUAyMC82NmIzNjQxXi9hNDIyYSM2ZWUuMmRzLzJhLS1kLTRzcw%3D%3D&btag=80000e00010000&cquery=106H&dy_q=1786968819&feature_id=f5241e7604dff1d9d6c943fd20bd51a2&l=20260817201339EA932CB59C644F0751AB',
  'https://v9-dy.ixigua.com/601b282ccb418df2e9a8cecbad2e4090/6a83091b/video/tos/cn/tos-cn-ve-15/ooGlZIpgJIgMNLXBIale01xUenLqC7AfzRQ2AB/?a=1768&br=5650&bt=5650&btag=80000e00008000&cd=0%7C0%7C0%7C0&ch=0&cr=0&cs=0&cv=1&dr=0&ds=4&dy_q=1786968835&dy_va_biz_cert=&er=0&feature_id=46a7bb47b4fd1280f3d3825bf2b29388&ft=ahW46QQqUuIf_oZmo0OW_QYaUqiXxp.y9VJEn_dWcbPD-Ipz&l=20260817201355EDC11C55406B8AFB861C&lr=unwatermarked&mime_type=video_mp4&net=5&qs=0&rc=NWdkNDQ0Ozo1NjhkOztpaEBpajdldnQ5cjx1NTMzNGkzM0BjM2JjNTFgNV8xMTY2YGE1YSNeNGtjMmRrL2BhLS1kLWFzcw%3D%3D&playAddrKey=v0d00fg10000d2cr29nog65qfsnb74ag',
  'https://v6-dy.ixigua.com/388ab9eaec25ca632b322133d7a3c44d/6a830937/video/tos/cn/tos-cn-ve-15/o8QAxFpaMBJTAyDBIffIqNggEq6N8Wvx8iMA9u/?a=0&ch=0&cr=0&dr=0&lr=normal&net=5&cd=0%7C0%7C0%7C0&cv=1&br=4827&bt=4827&cs=0&ds=4&ft=k7Fz7VVywIiRZm8Zmo~pK7pswApScsBVvrK9WB_jto0g3cI&mime_type=video_mp4&qs=0&rc=NTg4PGQ8PDlkaTU4ZTpkOEBpMzw4a3E5cmZmODMzNGkzM0BjY2NfMDEyNS0xMjJgYzI2YSNzcGtqMmRjM2BhLS1kLWFzcw%3D%3D&btag=80000e00008000&cquery=106H&dy_q=1786968863&feature_id=0ea98fd3bdc3c6c14a3d0804cc272721&l=2026081720142367C35219B9ECEAF539F5',
  'https://v9-dy.ixigua.com/3710e3dc8e3dddf87c430445ace50ea2/6a830950/video/tos/cn/tos-cn-ve-15/o8cISIwAvHpQcnxCAa32EPIT5QkNiiCKEaBDC/?a=1768&ch=0&cr=0&dr=0&er=0&lr=unwatermarked&net=5&cd=0%7C0%7C0%7C0&cv=1&br=5333&bt=5333&cs=0&ds=4&ft=ahW46QQqUuIf_oZmo0OW_QYaUqiXwp.y9VJEtyYvVbPD-Ipz&mime_type=video_mp4&qs=0&rc=aTc7NmZnZzw2ZGZoaTw5OEBpMzo4M2s5cjc7MzMzNGkzM0BhMzUwLi0xXjAxMl4tLi0wYSNiaWsxMmRrbmZhLS1kLWFzcw%3D%3D&btag=80000e00008000&dy_q=1786968884&feature_id=46a7bb47b4fd1280f3d3825bf2b29388&l=20260817201443BA38ABF6C463630E888F&playAddrKey=v0d00fg10000d0i8q4nog65h40n5l7e0',
  'https://v9-dy.ixigua.com/d8cc31fbb6f95c6c883f582fda989f0b/6a8309d3/video/tos/cn/tos-cn-ve-15/oEdYsoGqE9TuAFBBhgNQYgA7ljfVBqD1AITf9x/?a=1768&ch=0&cr=0&dr=0&er=0&lr=unwatermarked&net=5&cd=0%7C0%7C0%7C0&cv=1&br=1993&bt=1993&cs=0&ds=4&ft=ahW46QQqUnXfmoZmo0OW_QYaUqiXxk.y9VJE27ExrCPD-Ipz&mime_type=video_mp4&qs=0&rc=OmhkZDczZ2g8NzM2NTg6NUBpanJ1anQ5cjtoNDMzNGkzM0BjYjI0MDQvXjMxMjUtNmEvYSNuLm1uMmRzal9hLS1kLWFzcw%3D%3D&btag=80000e00028000&dy_q=1786968899&feature_id=46a7bb47b4fd1280f3d3825bf2b29388&l=202608172014590FF7EC57D0184CFC6C30&playAddrKey=v0d00fg10000d1bem8vog65qqgpr1oqg',
  'https://v9-dy.ixigua.com/54ae6f4e86873c8836a7a4f0d885926d/6a830969/video/tos/cn/tos-cn-ve-15/oAEEgssQex3I0AaqiK8UqNIIbPT4ABeiDW7AP6/?a=1768&ch=0&cr=0&dr=0&er=0&lr=unwatermarked&net=5&cd=0%7C0%7C0%7C0&cv=1&br=4591&bt=4591&cs=0&ds=4&ft=ahW46QQqUnXfmoZmo0OW_QYaUqiXLk.y9VJE27ExrCPD-Ipz&mime_type=video_mp4&qs=0&rc=ODNlODNkNDs4ODc4OjdmNUBpM2l5OWZrb2t1NTMzNGkzM0BiMC1gYTQ1XzUxX2BjYzBiYSNyaHJfcWdeZWRhLS1kLTBzcw%3D%3D&btag=80000e00008000&dy_q=1786968914&feature_id=46a7bb47b4fd1280f3d3825bf2b29388&l=20260817201514C8CB032C92BE2F219694&playAddrKey=v0300fg10000d2grhhaljhtcb6uvkfu0',
  'https://v11-default.365yg.com/11c2ef4b6d6ec2748f662b06ee8e762d/6a830979/video/tos/cn/tos-cn-ve-15/oYlFCABuQ39NBbMDwfjykIlXqjUxiDNfMgEgAA/?a=0&ch=0&cr=0&dr=0&lr=normal&net=5&cd=0%7C0%7C0%7C0&cv=1&br=6437&bt=6437&cs=0&ds=4&ft=k7Fz7VVywIiRZm8Zmo~pK7pswApE_sBVvrKoav_jto0g3cI&mime_type=video_mp4&qs=0&rc=NWg1NmU6ZDMzNWg4O2U8M0Bpamxpbms5cmo4OzMzNGkzM0A2Yy0wLTZeNTAxLTAxMzUvYSNkYjZwMmRzYW1hLS1kLWFzcw%3D%3D&btag=80000e00008000&cquery=106H&dy_q=1786968930&feature_id=37f92ebd2877ae8e7eba995d406c5150&l=20260817201530FF670AA36050A81E0318',
];

class PlayPage extends StatefulWidget {
  /// 全屏覆盖展示（隐蔽入口打开时为 true）
  final bool fullscreen;

  /// 全屏关闭回调
  final VoidCallback? onClose;

  const PlayPage({
    Key? key,
    this.fullscreen = false,
    this.onClose,
  }) : super(key: key);

  @override
  State<PlayPage> createState() => _PlayPageState();
}

class _PlayPageState extends State<PlayPage> {
  bool _showLaborLawPdf = false;
  bool _showLiangCalibrator = false;
  List<String>? _videoFeedUrls;
  String _videoFeedTitle = '赏心悦目';
  PdfControllerPinch? _pdfController;

  @override
  void dispose() {
    _pdfController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget content;
    if (_videoFeedUrls != null) {
      // 赏心悦目 / 风景面板从上到下全黑，不要外层白底+padding
      content = Container(
        color: const Color(0xFF111114),
        child: _buildShortVideoView(),
      );
    } else if (_showLiangCalibrator) {
      // 滑动变祖器直接撑满，不要外层 padding / 圆角
      content = SizedBox.expand(
        child: LiangCalibratorPage(
          onClose: () => setState(() => _showLiangCalibrator = false),
        ),
      );
    } else {
      final Widget body;
      if (_showLaborLawPdf) {
        body = _buildLaborLawPdfView();
      } else {
        body = _buildPlayCards();
      }
      content = Container(
        color: widget.fullscreen
            ? Colors.white.withValues(alpha: 0.92)
            : Colors.transparent,
        width: double.infinity,
        height: double.infinity,
        alignment: Alignment.topLeft,
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: body,
        ),
      );
    }

    if (!widget.fullscreen) return content;

    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.escape) {
          widget.onClose?.call();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          content,
          Positioned(
            top: 8,
            right: 8,
            child: Material(
              color: Colors.black.withValues(alpha: 0.45),
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: IconButton(
                tooltip: '关闭 (Esc)',
                onPressed: widget.onClose,
                icon: const Icon(Icons.close, color: Colors.white, size: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 默认展示的趣味功能卡片（每行最多 4 个）
  Widget _buildPlayCards() {
    const gap = 14.0;
    final items = <Widget>[
      _PlayFeatureCard(
        icon: Icons.restaurant_rounded,
        title: '吃什么',
        subtitle: '转盘帮你决定',
        accent: const Color(0xFFE07A5F),
        onTap: () => SmartDialogUtils.showFoodRoulette(),
      ),
      _PlayFeatureCard(
        icon: Icons.menu_book_rounded,
        title: '劳动法',
        subtitle: '摸鱼也要懂法',
        accent: const Color(0xFF5B7CFF),
        onTap: _openLaborLawPdf,
      ),
      _PlayFeatureCard(
        icon: Icons.music_note_rounded,
        title: '音乐播放',
        subtitle: '放点歌压压惊',
        accent: const Color(0xFF9B6BFF),
        onTap: _openMusicPlayer,
      ),
      _PlayFeatureCard(
        icon: Icons.terminal_rounded,
        title: '装忙模式',
        subtitle: '老板来了装认真',
        accent: const Color(0xFF2A9D8F),
        onTap: _openCodeRain,
      ),
      _PlayFeatureCard(
        icon: Icons.face_retouching_natural,
        title: '赏心悦目',
        subtitle: '刷一刷视频歇会儿',
        accent: const Color(0xFFE85D75),
        onTap: _openShortVideos,
      ),
      _PlayFeatureCard(
        icon: Icons.landscape_rounded,
        title: '风景',
        subtitle: '看看山河养养眼',
        accent: const Color(0xFF3D8B7A),
        onTap: _openLandscapeVideos,
      ),
      _PlayFeatureCard(
        icon: Icons.tune_rounded,
        title: '滑动变祖器',
        subtitle: '31 级梁系校准',
        accent: const Color(0xFFC23A2B),
        onTap: _openLiangCalibrator,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        const columns = 4;
        final itemWidth =
            (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final item in items)
              SizedBox(width: itemWidth, child: item),
          ],
        );
      },
    );
  }

  void _openShortVideos() {
    setState(() {
      _videoFeedTitle = '赏心悦目';
      _videoFeedUrls = _shortVideoUrls;
    });
  }

  void _openLandscapeVideos() {
    setState(() {
      _videoFeedTitle = '风景';
      _videoFeedUrls = _landscapeVideoUrls;
    });
  }

  Widget _buildShortVideoView() {
    final urls = _videoFeedUrls ?? _shortVideoUrls;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, top: 4),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () {
                  setState(() {
                    _videoFeedUrls = null;
                  });
                },
              ),
              const SizedBox(width: 4),
              Text(
                _videoFeedTitle,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ShortVideoPage(urls: urls),
        ),
      ],
    );
  }

  void _openCodeRain() {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: true,
        barrierColor: Colors.black,
        transitionDuration: const Duration(milliseconds: 120),
        pageBuilder: (_, __, ___) => const CodeRainPage(),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  void _openLiangCalibrator() {
    setState(() => _showLiangCalibrator = true);
  }

  void _openMusicPlayer() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const MusicPlayerDialog(),
    );
  }

  Future<void> _openLaborLawPdf() async {
    try {
      _pdfController?.dispose();
      final byteData = await rootBundle.load('assets/file/劳动法学习.pdf');
      _pdfController = PdfControllerPinch(
        document: PdfDocument.openData(
          byteData.buffer
              .asUint8List(byteData.offsetInBytes, byteData.lengthInBytes),
        ),
      );
      setState(() {
        _showLaborLawPdf = true;
      });
    } catch (e) {
      SmartDialogUtils.showError('打开劳动法文档失败: $e');
    }
  }

  Widget _buildLaborLawPdfView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () {
                setState(() {
                  _showLaborLawPdf = false;
                });
                _pdfController?.dispose();
                _pdfController = null;
              },
            ),
            const SizedBox(width: 8),
            const Text(
              '劳动法',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _pdfController == null
              ? const SizedBox.shrink()
              : PdfViewPinch(
                  controller: _pdfController!,
                  backgroundDecoration: const BoxDecoration(
                    color: Color.fromARGB(255, 250, 250, 250),
                  ),
                ),
        ),
      ],
    );
  }
}

/// 玩一玩入口卡片：浅底 + 色点缀，避免整块高饱和渐变抢戏
class _PlayFeatureCard extends StatefulWidget {
  const _PlayFeatureCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;
  final VoidCallback onTap;

  @override
  State<_PlayFeatureCard> createState() => _PlayFeatureCardState();
}

class _PlayFeatureCardState extends State<_PlayFeatureCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final accent = widget.accent;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        height: 118,
        transform: Matrix4.translationValues(0, _hovered ? -2 : 0, 0),
        transformAlignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: _hovered ? 0.96 : 0.88),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _hovered
                ? accent.withValues(alpha: 0.35)
                : Colors.black.withValues(alpha: 0.06),
          ),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: _hovered ? 0.18 : 0.08),
              blurRadius: _hovered ? 18 : 12,
              offset: Offset(0, _hovered ? 8 : 4),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            splashColor: accent.withValues(alpha: 0.12),
            highlightColor: accent.withValues(alpha: 0.06),
            onTap: widget.onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(widget.icon, color: accent, size: 36),
                  const SizedBox(height: 10),
                  Text(
                    widget.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF2C2C2E),
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.black.withValues(alpha: 0.42),
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
