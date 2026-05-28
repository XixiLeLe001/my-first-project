import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: AccountStore
    @State private var showLogin = false
    @State private var expandedPins: Set<String> = []
    @State private var secretAccount: JDAccount?

    var body: some View {
        ZStack {
            LeSciBackground()

            VStack(spacing: 0) {
                HeaderView()
                    .padding(.top, 58)
                    .padding(.horizontal, 24)

                if !store.remoteControl.isAllowed {
                    RemoteNoticeView(message: store.remoteControl.message)
                        .padding(.horizontal, 22)
                        .padding(.top, 20)
                } else if let error = store.lastError {
                    ErrorNoticeView(message: error)
                        .padding(.horizontal, 22)
                        .padding(.top, 20)
                }

                if store.visibleAccounts.isEmpty {
                    EmptyAccountView(copy: store.emptyCopy)
                        .padding(.horizontal, 22)
                        .padding(.top, 98)
                } else {
                    AccountStatusView(text: store.accountStatusText)
                        .padding(.horizontal, 22)
                        .padding(.top, 54)

                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 16) {
                            ForEach(store.visibleAccounts) { account in
                                AccountCard(
                                    account: account,
                                    isExpanded: expandedPins.contains(account.pin),
                                    onToggle: { toggle(account) },
                                    onSecret: { secretAccount = account },
                                    onDeleteDisplay: { store.hideAccountFromDisplay(account) }
                                )
                            }
                        }
                        .padding(.horizontal, 22)
                        .padding(.top, 22)
                        .padding(.bottom, 22)
                    }
                }

                Spacer(minLength: 16)

                if !store.visibleAccounts.isEmpty {
                    ContactRow()
                        .environmentObject(store)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 18)
                }

                Button {
                    showLogin = true
                } label: {
                    Label("添加京东账号", systemImage: "plus")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 66)
                        .background(Color(red: 0.08, green: 0.56, blue: 0.98), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .shadow(color: Color.blue.opacity(0.24), radius: 10, y: 7)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 22)
                .padding(.bottom, 28)
            }

            if let toast = store.toast {
                ToastView(text: toast)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(2)
            }
        }
        .animation(.spring(response: 0.28, dampingFraction: 0.86), value: store.toast)
        .sheet(isPresented: $showLogin) {
            JDLoginView()
                .environmentObject(store)
        }
        .sheet(item: $secretAccount) { account in
            SecretDataSheet(account: account) {
                store.copySecret(for: account)
                secretAccount = nil
            }
        }
    }

    private func toggle(_ account: JDAccount) {
        if expandedPins.contains(account.pin) {
            expandedPins.remove(account.pin)
        } else {
            expandedPins.insert(account.pin)
        }
    }
}

private struct LeSciBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(red: 0.95, green: 0.99, blue: 1.0),
                Color(red: 0.86, green: 0.94, blue: 1.0),
                Color(red: 0.97, green: 0.99, blue: 1.0)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}

private struct HeaderView: View {
    var body: some View {
        HStack(spacing: 20) {
            LeSciLogo()
                .frame(width: 74, height: 74)
            Text("LeSci")
                .font(.system(size: 42, weight: .heavy))
                .foregroundColor(Color(red: 0.02, green: 0.06, blue: 0.24))
            Spacer()
        }
    }
}

private struct LeSciLogo: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(red: 0.03, green: 0.49, blue: 1.0), Color(red: 0.09, green: 0.92, blue: 0.86)],
                        startPoint: .bottomLeading,
                        endPoint: .topTrailing
                    )
                )
            Image(systemName: "face.smiling")
                .font(.system(size: 38, weight: .semibold))
                .foregroundColor(.white)
        }
        .shadow(color: Color.blue.opacity(0.18), radius: 12, y: 7)
    }
}

private struct AccountStatusView: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 17, weight: .semibold))
            .multilineTextAlignment(.center)
            .lineSpacing(5)
            .foregroundColor(Color(red: 0.04, green: 0.45, blue: 0.88))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .padding(.horizontal, 18)
            .background(.white.opacity(0.82), in: Capsule())
            .overlay(Capsule().stroke(.white, lineWidth: 1))
    }
}

private struct EmptyAccountView: View {
    let copy: (title: String, subtitle: String)

    var body: some View {
        VStack(spacing: 22) {
            Spacer()
            ZStack {
                Circle()
                    .fill(Color(red: 0.78, green: 0.9, blue: 1.0))
                    .frame(width: 76, height: 76)
                Image(systemName: "ellipsis.message.fill")
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundColor(Color(red: 0.05, green: 0.46, blue: 0.9))
            }
            Text(copy.title)
                .font(.system(size: 32, weight: .heavy))
                .foregroundColor(Color(red: 0.02, green: 0.06, blue: 0.24))
                .multilineTextAlignment(.center)
            Text(copy.subtitle)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(Color(red: 0.42, green: 0.48, blue: 0.62))
                .multilineTextAlignment(.center)
                .lineSpacing(6)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .frame(height: 560)
        .padding(.horizontal, 18)
        .background(.white.opacity(0.54), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }
}

private struct AccountCard: View {
    let account: JDAccount
    let isExpanded: Bool
    let onToggle: () -> Void
    let onSecret: () -> Void
    let onDeleteDisplay: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 16) {
                Button(action: onSecret) {
                    AvatarView(account: account)
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 10) {
                    Text(account.displayName)
                        .font(.system(size: 24, weight: .heavy))
                        .foregroundColor(Color(red: 0.02, green: 0.06, blue: 0.24))
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)

                    HStack(spacing: 10) {
                        MemberBadge(levelName: account.levelName, levelIcon: account.levelIcon)
                        ValueBadge(title: "京享值", value: account.jingXiangValue)
                        ValueBadge(title: "", value: account.totalBean, suffix: "京豆")
                    }

                    Text("上传时间: \(account.uploadTime)")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(Color(red: 0.41, green: 0.47, blue: 0.58))
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }

                Spacer(minLength: 4)

                VStack(alignment: .trailing, spacing: 28) {
                    StatusPill(isValid: account.isValid)
                    Button(action: onToggle) {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(Color(red: 0.02, green: 0.06, blue: 0.24))
                            .frame(width: 36, height: 36)
                    }
                    .buttonStyle(.plain)
                }
            }

            if isExpanded {
                VStack(spacing: 18) {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 18), count: 3), spacing: 18) {
                        StatCell(title: "今日", value: "\(account.todayBean)")
                        StatCell(title: "昨日", value: "\(account.yesterdayBean)")
                        StatCell(title: "即将过期", value: "\(account.expireSoonBean)")
                        StatCell(title: "总京豆", value: "\(account.totalBean)")
                        StatCell(title: "红包总额", value: String(format: "%.2f", account.redpacketTotal))
                        StatCell(title: "红包过期", value: String(format: "%.2f", account.redpacketExpire))
                    }

                    if !account.checkedAt.isEmpty {
                        HStack {
                            Image(systemName: "clock")
                            Text("更新时间: \(account.checkedAt)")
                            Spacer()
                        }
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color(red: 0.42, green: 0.48, blue: 0.62))
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("最近京豆明细")
                            .font(.system(size: 20, weight: .heavy))
                            .foregroundColor(Color(red: 0.02, green: 0.06, blue: 0.24))
                        if account.recentBeanDetails.isEmpty {
                            Text("暂无明细")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(Color(red: 0.48, green: 0.54, blue: 0.64))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 18)
                        } else {
                            ForEach(account.recentBeanDetails.prefix(3)) { detail in
                                BeanDetailRow(detail: detail)
                            }
                        }
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(20)
        .background(.white.opacity(0.86), in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).stroke(.white.opacity(0.92), lineWidth: 1))
        .shadow(color: Color.black.opacity(0.08), radius: 10, y: 5)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if !isExpanded {
                Button(role: .destructive, action: onDeleteDisplay) {
                    Label("删除", systemImage: "trash")
                }
            }
        }
    }
}

private struct AvatarView: View {
    let account: JDAccount

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(Color.yellow.opacity(0.86))
                    .frame(width: 82, height: 82)
                if let url = URL(string: account.avatarURL), !account.avatarURL.isEmpty {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        Image(systemName: "face.smiling")
                            .font(.system(size: 38, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .frame(width: 82, height: 82)
                    .clipShape(Circle())
                } else {
                    Image(systemName: "face.smiling")
                        .font(.system(size: 38, weight: .semibold))
                        .foregroundColor(.white)
                }
            }

            if account.isPlusVip {
                Text("PLUS")
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundColor(Color(red: 0.95, green: 0.79, blue: 0.43))
                    .padding(.horizontal, 18)
                    .padding(.vertical, 5)
                    .background(Color(red: 0.15, green: 0.14, blue: 0.12), in: Capsule())
            }
        }
    }
}

private struct MemberBadge: View {
    let levelName: String
    let levelIcon: String

    var body: some View {
        HStack(spacing: 6) {
            if levelIcon.isEmpty {
                Text("JD")
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 5)
                    .background(Color.gray.opacity(0.85), in: Capsule())
            } else {
                AsyncImage(url: URL(string: levelIcon)) { image in
                    image.resizable().scaledToFit()
                } placeholder: {
                    Text("JD")
                        .font(.system(size: 12, weight: .heavy))
                        .foregroundColor(.white)
                }
                .frame(width: 24, height: 24)
            }
            Text(levelName.isEmpty ? "普通会员" : levelName)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(Color(red: 0.34, green: 0.37, blue: 0.44))
                .lineLimit(1)
                .minimumScaleFactor(0.78)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Color.white.opacity(0.9), in: Capsule())
        .overlay(Capsule().stroke(Color.black.opacity(0.05), lineWidth: 1))
    }
}

private struct ValueBadge: View {
    let title: String
    let value: Int
    var suffix = ""

    var body: some View {
        Text("\(title.isEmpty ? "" : "\(title) ")\(value)\(suffix)")
            .font(.system(size: 14, weight: .heavy))
            .foregroundColor(title.isEmpty ? Color(red: 0.02, green: 0.47, blue: 0.88) : Color(red: 0.37, green: 0.22, blue: 0.78))
            .lineLimit(1)
            .minimumScaleFactor(0.72)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(title.isEmpty ? Color(red: 0.90, green: 0.97, blue: 1.0) : Color(red: 0.94, green: 0.90, blue: 1.0), in: Capsule())
    }
}

private struct StatusPill: View {
    let isValid: Bool

    var body: some View {
        HStack(spacing: 9) {
            Circle()
                .fill(isValid ? Color.green : Color.red)
                .frame(width: 14, height: 14)
            Text(isValid ? "有效" : "失效")
                .font(.system(size: 20, weight: .heavy))
                .foregroundColor(isValid ? Color.green : Color.red)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
        .background(.white.opacity(0.74), in: Capsule())
    }
}

private struct StatCell: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color(red: 0.42, green: 0.48, blue: 0.62))
            Text(value)
                .font(.system(size: 20, weight: .heavy))
                .foregroundColor(Color(red: 0.02, green: 0.06, blue: 0.24))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct BeanDetailRow: View {
    let detail: BeanDetail

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "plus")
                .font(.system(size: 15, weight: .heavy))
                .foregroundColor(Color.green)
                .frame(width: 34, height: 34)
                .background(Color.green.opacity(0.12), in: Circle())
            VStack(alignment: .leading, spacing: 4) {
                Text(detail.title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(Color(red: 0.02, green: 0.06, blue: 0.24))
                    .lineLimit(1)
                if !detail.time.isEmpty {
                    Text(detail.time)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color(red: 0.42, green: 0.48, blue: 0.62))
                        .lineLimit(1)
                }
            }
            Spacer()
            Text(detail.amount >= 0 ? "+\(detail.amount)" : "\(detail.amount)")
                .font(.system(size: 18, weight: .heavy))
                .foregroundColor(Color(red: 0.02, green: 0.47, blue: 0.88))
        }
    }
}

private struct ContactRow: View {
    @EnvironmentObject private var store: AccountStore

    var body: some View {
        HStack(spacing: 12) {
            Button(action: store.copyQQRobot) {
                Label("QQ机器人: \(LeSciConfig.qqRobot)", systemImage: "bell.fill")
            }
            Divider().frame(height: 18)
            Button(action: store.copyWechatRobot) {
                Label("微信机器人: \(LeSciConfig.wechatRobot)", systemImage: "message.fill")
            }
        }
        .font(.system(size: 13, weight: .bold))
        .foregroundColor(Color(red: 0.02, green: 0.47, blue: 0.88))
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .overlay(alignment: .top) { Divider().opacity(0.35) }
        .overlay(alignment: .bottom) { Divider().opacity(0.35) }
    }
}

private struct SecretDataSheet: View {
    let account: JDAccount
    let onCopy: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            Text("神秘数据")
                .font(.system(size: 32, weight: .heavy))
                .foregroundColor(Color(red: 0.02, green: 0.06, blue: 0.24))

            ScrollView {
                Text(account.cookie)
                    .font(.system(size: 18, weight: .medium, design: .monospaced))
                    .foregroundColor(Color(red: 0.02, green: 0.06, blue: 0.24))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(18)
            }
            .frame(maxHeight: 220)
            .background(Color(red: 0.94, green: 0.97, blue: 1.0), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.blue.opacity(0.18), lineWidth: 1))

            HStack(spacing: 16) {
                Button {
                    dismiss()
                } label: {
                    Text("关闭")
                        .font(.system(size: 20, weight: .heavy))
                        .foregroundColor(Color(red: 0.02, green: 0.47, blue: 0.88))
                        .frame(maxWidth: .infinity)
                        .frame(height: 58)
                        .background(.white, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 15, style: .continuous).stroke(Color.blue.opacity(0.18), lineWidth: 1))
                }

                Button(action: onCopy) {
                    Text("复制")
                        .font(.system(size: 20, weight: .heavy))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 58)
                        .background(Color(red: 0.08, green: 0.48, blue: 0.98), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                }
            }
        }
        .padding(26)
    }
}

private struct RemoteNoticeView: View {
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("App 服务通知")
                .font(.system(size: 18, weight: .heavy))
            Text(message.isEmpty ? "当前版本已停止服务，请按机器人通知前往指定位置下载最新版。" : message)
                .font(.system(size: 15, weight: .semibold))
        }
        .foregroundColor(Color(red: 0.72, green: 0.10, blue: 0.16))
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.white.opacity(0.84), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct ErrorNoticeView: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.system(size: 17, weight: .heavy))
            .foregroundColor(Color(red: 0.72, green: 0.10, blue: 0.16))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(Color.white.opacity(0.84), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct ToastView: View {
    let text: String

    var body: some View {
        VStack {
            Spacer()
            Text(text)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(Color(red: 0.25, green: 0.32, blue: 0.46))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 22)
                .padding(.vertical, 14)
                .background(.white.opacity(0.92), in: Capsule())
                .shadow(color: Color.black.opacity(0.12), radius: 12, y: 5)
                .padding(.bottom, 104)
        }
    }
}
