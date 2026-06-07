//
//  ReportsView.swift
//  PickandDrop
//
//  Created by Ronald Thayer Jr on 5/7/26.
//

import SwiftUI
import SwiftData
import QuickLook

struct ReportsView: View {

    @State private var settings: SupabaseCompanySettings?
    @State private var weeklyInvoiceURL: URL?
    @State private var selectedInvoiceWeek = Date()
    
    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.08, green: 0.11, blue: 0.18),
                        Color(red: 0.15, green: 0.22, blue: 0.35),
                        Color.black.opacity(0.95)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 22) {

                        headerCard

                        DatePicker(
                            "Invoice Week",
                            selection: $selectedInvoiceWeek,
                            displayedComponents: .date
                        )
                        .padding()
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                        .foregroundStyle(.white)
                        
                        Button {

                            Task {

                                if let settings {

                                    let loads =
                                        await LoadSupabaseManager.shared.fetchLoads()

                                    weeklyInvoiceURL =
                                        WeeklyInvoiceGenerator.createWeeklyInvoicePDF(
                                            settings: settings,
                                            weekDate: selectedInvoiceWeek,
                                            loads: loads
                                        )
                                }
                            }

                        } label: {
                            reportCard(
                                title: "Weekly Invoice",
                                subtitle: "Generate weekly invoice PDF",
                                icon: "doc.richtext.fill",
                                color: .blue
                            )
                        }

                        NavigationLink {
                            DailyDriverSummaryView()
                        } label: {
                            reportCard(
                                title: "Daily Driver Summary",
                                subtitle: "Driver loads and tons by day",
                                icon: "person.3.fill",
                                color: .green
                            )
                        }

                        NavigationLink {
                            CompletedLoadsReportView()
                        } label: {
                            reportCard(
                                title: "Completed Loads",
                                subtitle: "Delivered Supabase loads",
                                icon: "checkmark.circle.fill",
                                color: .orange
                            )
                        }

                        NavigationLink {
                            FuelReportsView()
                        } label: {
                            reportCard(
                                title: "Fuel Reports",
                                subtitle: "Fuel totals from Supabase",
                                icon: "fuelpump.fill",
                                color: .red
                            )
                        }
                    }
                    .padding()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .onAppear {
                Task {
                    let loadedSettings =
                        await CompanySupabaseManager.shared.fetchCompanySettings()

                    await MainActor.run {
                        settings = loadedSettings
                    }
                }
            }
            .quickLookPreview($weeklyInvoiceURL)
        }
    }

    var headerCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Reports")
                .font(.system(size: 38, weight: .bold))
                .foregroundStyle(.white)

            Text(settings?.trucking_company_name ?? "Trucking Company")
                .font(.headline)
                .foregroundStyle(.blue)

            Text(
                "\(settings?.pickup_company_name ?? "Pickup") → \(settings?.dropoff_company_name ?? "Dropoff")"
            )
            .font(.caption)
            .foregroundStyle(.white.opacity(0.7))

            Text("Supabase Reports")
                .foregroundStyle(.white.opacity(0.7))

            Divider()

            HStack {
                reportStat(title: "Source", value: "Live")
                Spacer()
                reportStat(title: "Files", value: "0")
                Spacer()
                reportStat(title: "CSV Legacy", value: "Off")
            }
        }
        .padding(24)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 30))
    }

    func reportCard(
        title: String,
        subtitle: String,
        icon: String,
        color: Color
    ) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
                .frame(width: 44, height: 44)
                .background(color.opacity(0.18))
                .clipShape(RoundedRectangle(cornerRadius: 14))

            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.white)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundStyle(.white.opacity(0.4))
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 22))
    }

    func reportStat(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.7))

            Text(value)
                .font(.title3.bold())
                .foregroundStyle(.white)
        }
    }
}

