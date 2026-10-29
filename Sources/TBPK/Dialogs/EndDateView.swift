import SwiftUI

struct EndDateView: View {
    @ObservedObject var model: EndDateModel
    var onSet: (Date) -> Void
    var onCancel: () -> Void

    private let calendar = Calendar.current
    private let gridColumns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            content(now: context.date)
                .onChange(of: context.date) { model.normalize(now: $0) }
        }
        .padding(24)
        .frame(width: 400)
        .environment(\.locale, Locale(identifier: "en_GB"))
        .environment(\.calendar, Calendar(identifier: .gregorian))
    }

    private func content(now: Date) -> some View {
        let ahead = model.isAhead(now: now)
        return VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 2) {
                Text(model.headline(now: now))
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(ahead ? Color.primary : Color.red)
                Text(model.detail(now: now))
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            Picker("", selection: $model.mode) {
                ForEach(EndDateModel.Mode.allCases) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            switch model.mode {
            case .duration: durationControls
            case .time: timeControls(now: now)
            }

            HStack {
                Button("Cancel", action: onCancel).keyboardShortcut(.cancelAction)
                Spacer()
                Button(model.confirmTitle(now: now)) {
                    if let moment = model.moment(now: Date()) { model.remember(); onSet(moment) }
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(!ahead)
            }
        }
    }

    private var durationControls: some View {
        VStack(alignment: .leading, spacing: 14) {
            LazyVGrid(columns: gridColumns, spacing: 8) {
                ForEach(EndDateModel.chips) { chip in
                    chipButton(chip.label, selected: model.isChipSelected(chip)) { model.applyChip(minutes: chip.minutes) }
                }
            }
            HStack(spacing: 10) {
                Text("Or any length").foregroundStyle(.secondary)
                Spacer()
                TextField("", value: $model.amount, format: .number.grouping(.never))
                    .multilineTextAlignment(.trailing)
                    .frame(width: 64)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: model.amount) { _ in model.normalize(now: Date()) }
                Stepper("", value: $model.amount, in: 0...EndDateUnit.largestAmount).labelsHidden()
                Picker("", selection: $model.unit) {
                    ForEach(EndDateUnit.allCases, id: \.self) { Text($0.label).tag($0) }
                }
                .labelsHidden()
                .frame(width: 100)
            }
            minutesRow
        }
    }

    // After What's new pointed here, the new row is tinted and tagged so the eye lands on it.
    private var minutesRow: some View {
        HStack(spacing: 10) {
            Text("And").foregroundStyle(model.tipsMinutes ? Color(nsColor: MenuHighlight.newColor) : Color.secondary)
            if model.tipsMinutes {
                Text("NEW").font(.caption2.weight(.bold)).foregroundStyle(.white)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Capsule().fill(Color(nsColor: MenuHighlight.newColor)))
            }
            Spacer()
            TextField("", value: $model.extraMinutes, format: .number.grouping(.never))
                .multilineTextAlignment(.trailing)
                .frame(width: 64)
                .textFieldStyle(.roundedBorder)
                .onChange(of: model.extraMinutes) { _ in model.normalize(now: Date()) }
            Stepper("", value: $model.extraMinutes, in: 0...59).labelsHidden()
            Text("minutes").frame(width: 100, alignment: .leading)
    }
        .padding(model.tipsMinutes ? 8 : 0)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color(nsColor: MenuHighlight.newColor).opacity(model.tipsMinutes ? 0.14 : 0)))
    }

    private func timeControls(now: Date) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                sectionTitle("Day")
                HStack(spacing: 6) {
                    if model.isTodayAvailable(now: now) {
                        chipButton("Today", selected: model.isDayChosen(offsetFrom: now, days: 0)) {
                            model.chooseDay(offsetFrom: now, days: 0)
                        }
                    }
                    chipButton("Tomorrow", selected: model.isDayChosen(offsetFrom: now, days: 1)) {
                        model.chooseDay(offsetFrom: now, days: 1)
                    }
                    Spacer(minLength: 4)
                    DatePicker("", selection: dayBinding(now: now), in: model.firstSelectableDay(now: now)..., displayedComponents: .date)
                        .labelsHidden()
                        .padding(.trailing, 8)
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                sectionTitle("Time")
                HStack(spacing: 8) {
                    clockDigits($model.clockHour, range: model.hourRange(now: now))
                    Text(":").font(.system(size: 34, weight: .light)).foregroundStyle(.secondary)
                    clockDigits($model.clockMinute, range: model.minuteRange(now: now))
                    Spacer()
                }
                let hours = model.availableClockHours(now: now)
                if !hours.isEmpty {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 6) {
                        ForEach(hours, id: \.self) { hour in
                            chipButton(String(format: "%02d:00", hour), selected: model.clockHour == hour && model.clockMinute == 0) {
                                model.applyClock(hour: hour, now: Date())
                            }
                        }
                    }
                }
            }
        }
    }

    private func dayBinding(now: Date) -> Binding<Date> {
        Binding(get: { model.day }, set: { model.day = $0; model.normalize(now: Date()) })
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text.uppercased()).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
    }

    private func clockDigits(_ value: Binding<Int>, range: ClosedRange<Int>) -> some View {
        HStack(spacing: 4) {
            TextField("", value: value, format: .number.precision(.integerLength(2)))
                .textFieldStyle(.plain)
                .font(.system(size: 32, weight: .medium).monospacedDigit())
                .multilineTextAlignment(.center)
                .frame(width: 76, height: 56)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.08)))
                .onChange(of: value.wrappedValue) { _ in model.normalize(now: Date()) }
            Stepper("", value: value, in: range).labelsHidden()
        }
    }

    private func chipButton(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).frame(maxWidth: .infinity).padding(.vertical, 6)
        }
        .buttonStyle(.plain)
        .background(RoundedRectangle(cornerRadius: 8).fill(selected ? Color.accentColor : Color.primary.opacity(0.08)))
        .foregroundStyle(selected ? Color.white : Color.primary)
    }
}
