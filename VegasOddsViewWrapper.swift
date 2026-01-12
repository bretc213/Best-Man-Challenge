//
//  VegasOddsViewWrapper.swift
//  Best Man Challenge
//
//  Created by Bret Clemetson on 5/24/25.
//

import SwiftUI

struct VegasOddsViewWrapper: View {
    @Binding var allSlips: [BetSlip]

    var body: some View {
        VegasOddsView(allSlips: $allSlips)
    }
}


