import SwiftUI
import SwiftData

struct DailyTimeTicketView: View {
    
    @State private var shifts: [SupabaseShift] = []
    @State private var isLoading = true
    
    @State private var selectedDate = Date()
    @State private var selectedDriver = "All Drivers"
    
    private var driverNames: [String] {
        
        let names =
        Set(
            shifts.map {
                $0.driver_name
            }
        )
        
        return ["All Drivers"] +
        names.sorted()
    }
    
    private var finishedShifts: [SupabaseShift] {
        
        shifts.filter {
            $0.status == "finished" &&
            $0.ended_at != nil
        }
    }
    
    private func date(
        from string: String
    ) -> Date? {
        
        ISO8601DateFormatter()
            .date(from: string)
    }
    
    private func startDate(
        for shift: SupabaseShift
    ) -> Date? {
        
        date(from: shift.started_at)
    }
    
    private func endDate(
        for shift: SupabaseShift
    ) -> Date? {
        
        guard let endedAt = shift.ended_at else {
            return nil
        }
        
        return date(from: endedAt)
    }
    
    private var datesWithData: [Date] {
        
        let calendar = Calendar.current
        
        let dates: [Date] =
        finishedShifts.compactMap { shift -> Date? in
            
            guard let start =
                    startDate(for: shift)
            else {
                return nil
            }
            
            return calendar.startOfDay(
                for: start
            )
        }
        
        return Array(Set(dates))
            .sorted(by: >)
    }
    
    private var filteredShifts: [SupabaseShift] {
        
        finishedShifts
            .filter { shift in
                
                guard let start =
                        startDate(for: shift)
                else {
                    return false
                }
                
                let sameDay =
                Calendar.current.isDate(
                    start,
                    inSameDayAs: selectedDate
                )
                
                let correctDriver =
                selectedDriver == "All Drivers" ||
                shift.driver_name == selectedDriver
                
                return sameDay && correctDriver
            }
            .sorted {
                
                guard
                    let first = startDate(for: $0),
                    let second = startDate(for: $1)
                else {
                    return false
                }
                
                return first < second
            }
    }
    
    private var totalSeconds: TimeInterval {
        
        filteredShifts.reduce(0) {
            total,
            shift in
            
            guard
                let start = startDate(for: shift),
                let end = endDate(for: shift)
            else {
                return total
            }
            
            return total +
            end.timeIntervalSince(start)
        }
    }
    
    var body: some View {
        
        List {
            
            // MARK: Date
            
            Section("Report Date") {
                
                DatePicker(
                    "Date",
                    selection: $selectedDate,
                    displayedComponents: .date
                )
            }
            
            // MARK: Dates With Data
            
            if !datesWithData.isEmpty {
                
                Section("Dates With Time Data") {
                    
                    ScrollView(
                        .horizontal,
                        showsIndicators: false
                    ) {
                        
                        HStack(spacing: 10) {
                            
                            ForEach(
                                datesWithData,
                                id: \.self
                            ) { date in
                                
                                Button {
                                    
                                    selectedDate = date
                                    
                                } label: {
                                    
                                    VStack(spacing: 4) {
                                        
                                        Text(
                                            date.formatted(
                                                .dateTime
                                                    .month(
                                                        .abbreviated
                                                    )
                                            )
                                        )
                                        .font(.caption)
                                        
                                        Text(
                                            date.formatted(
                                                .dateTime
                                                    .day()
                                            )
                                        )
                                        .font(
                                            .title3.bold()
                                        )
                                    }
                                    .frame(
                                        width: 54,
                                        height: 54
                                    )
                                    .foregroundStyle(
                                        isSelected(date)
                                        ? .white
                                        : .green
                                    )
                                    .background(
                                        isSelected(date)
                                        ? Color.blue
                                        : Color.green
                                            .opacity(0.18)
                                    )
                                    .clipShape(
                                        RoundedRectangle(
                                            cornerRadius: 14
                                        )
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            
            // MARK: Driver
            
            Section("Driver") {
                
                Picker(
                    "Driver",
                    selection: $selectedDriver
                ) {
                    
                    ForEach(
                        driverNames,
                        id: \.self
                    ) { name in
                        
                        Text(name)
                            .tag(name)
                    }
                }
            }
            
            // MARK: Ticket
            
            Section {
                
                if filteredShifts.isEmpty {
                    
                    ContentUnavailableView(
                        "No Time Ticket",
                        systemImage:
                            "clock.badge.xmark",
                        description: Text(
                            "No finished shifts were found for this date."
                        )
                    )
                    
                } else {
                    
                    ForEach(
                        filteredShifts
                    ) { shift in
                        
                        TimeTicketRow(
                            shift: shift
                        )
                    }
                }
                
            } header: {
                
                Text(
                    selectedDate.formatted(
                        date: .long,
                        time: .omitted
                    )
                )
            }
            
            // MARK: Total
            
            if !filteredShifts.isEmpty {
                
                Section("Daily Total") {
                    
                    HStack {
                        
                        Label(
                            "Total Hours",
                            systemImage:
                                "clock.fill"
                        )
                        
                        Spacer()
                        
                        Text(
                            formattedDuration(
                                totalSeconds
                            )
                        )
                        .font(.title3.bold())
                        .foregroundStyle(.blue)
                    }
                }
            }
        }
        .task {
            
            isLoading = true
            
            shifts =
            await ShiftSupabaseManager.shared
                .fetchShifts()
            
            isLoading = false
        }
        .navigationTitle(
            "Daily Time Ticket"
        )
        .navigationBarTitleDisplayMode(
            .inline
        )
    }
    
    private func isSelected(
        _ date: Date
    ) -> Bool {
        
        Calendar.current.isDate(
            date,
            inSameDayAs: selectedDate
        )
    }
    
    private func formattedDuration(
        _ seconds: TimeInterval
    ) -> String {
        
        let totalMinutes =
        max(
            0,
            Int(seconds) / 60
        )
        
        let hours =
        totalMinutes / 60
        
        let minutes =
        totalMinutes % 60
        
        return "\(hours) hr \(minutes) min"
    }
}


// MARK: - Row

private struct TimeTicketRow: View {
    
    let shift: SupabaseShift
    
    var body: some View {
        
        VStack(
            alignment: .leading,
            spacing: 14
        ) {
            
            HStack {
                
                Text(shift.driver_name)
                    .font(.headline)
                
                Spacer()
                
                Text(durationText)
                    .fontWeight(.bold)
                    .foregroundStyle(.blue)
            }
            
            if let start = parsedDate(
                shift.started_at
            ) {
                
                HStack {
                    
                    Label(
                        "Start Day",
                        systemImage:
                            "play.circle.fill"
                    )
                    .foregroundStyle(.green)
                    
                    Spacer()
                    
                    Text(
                        start.formatted(
                            date: .omitted,
                            time: .shortened
                        )
                    )
                    .monospacedDigit()
                }
            }
            
            if
                let endedAt = shift.ended_at,
                let end = parsedDate(endedAt)
            {
                
                HStack {
                    
                    Label(
                        "End Day",
                        systemImage:
                            "stop.circle.fill"
                    )
                    .foregroundStyle(.red)
                    
                    Spacer()
                    
                    Text(
                        end.formatted(
                            date: .omitted,
                            time: .shortened
                        )
                    )
                    .monospacedDigit()
                }
            }
        }
        .padding(.vertical, 6)
    }
    
    private var durationText: String {
        
        guard
            let start = parsedDate(
                shift.started_at
            ),
            let endedAt = shift.ended_at,
            let end = parsedDate(
                endedAt
            )
        else {
            return "—"
        }
        
        let seconds =
        end.timeIntervalSince(start)
        
        let totalMinutes =
        max(
            0,
            Int(seconds) / 60
        )
        
        let hours =
        totalMinutes / 60
        
        let minutes =
        totalMinutes % 60
        
        return "\(hours) hr \(minutes) min"
    }
    
    private func parsedDate(
        _ string: String
    ) -> Date? {
        
        ISO8601DateFormatter()
            .date(from: string)
    }
}
