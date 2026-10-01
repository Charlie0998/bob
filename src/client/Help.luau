-- The "?" Help panel: common questions (tap one to open its answer),
-- how-to-play guides with a Replay tutorial button, and everything else
-- (pearls and shells, settings, controls).

local UIKit = require(script.Parent.UIKit)

local COLORS = UIKit.COLORS
local make = UIKit.make

local FAQ = {
	{ "How do I get pearls?", "Plant corals in your sand slots. When a coral says Ready, tap it to harvest pearls. You can also tap swimming fish, feed visiting sea creatures, and finish daily Goals." },
	{ "Why is my coral not ready?", "Every coral takes time to grow. The timer over it shows how long is left. Bigger, rarer corals take longer but give more pearls." },
	{ "Do my corals grow when I leave?", "Yes! Corals keep growing for up to 8 hours while you're away, so come back and harvest." },
	{ "How do I get more slots?", "Tap the giant clam in front of your reef. Each new slot costs a few more pearls than the last." },
	{ "What are shells for?", "Shells are a rare currency. Spend them in the Shop on special corals and decorations. You get shells from Goals, finds, the tutorial, and friends." },
	{ "What is Reef Health?", "A healthy reef has lots of different corals and full slots. The healthier your reef, the more pearls every harvest gives." },
	{ "What is a Rebirth (Tide Reset)?", "Once your reef is big enough, open the Shop and do a Tide Reset. Your reef starts fresh, but every harvest gives more pearls forever after." },
	{ "How do I trade?", "Tap Trade in the menu, or visit Captain Kai at the Trade Post in the Market. Pick a player, add corals, and both press Ready, then Confirm." },
	{ "How do I visit friends?", "Tap Travel in the menu to visit anyone's reef. Visiting gives you both a bonus, and you can like their reef." },
	{ "What is the friend bonus?", "When a friend joins your server, you both get pearls and shells once. Friends on the same server also give everyone a small pearl boost." },
	{ "Where are the leaderboards?", "Follow the path off the ring road to the Leaderboard area under the jellyfish: Most Rebirths, Most Shells, Most Pearls, and Top Reefs this week." },
	{ "The game feels slow. What can I do?", "Tap the Graphics button in the bottom-left to switch to Low. The game plays the same, just smoother." },
}

local GUIDES = {
	{ "1. Plant", "Pick a coral in the bar at the bottom of the screen, then tap an empty shell slot on your reef. It costs pearls." },
	{ "2. Harvest", "When a coral says Ready, tap it. Pearls fly to your counter at the top." },
	{ "3. Grow your reef", "Tap the giant clam in front of your reef to buy a new slot. More slots unlock new corals and decorations." },
	{ "4. Shop at the Market", "The Market is in the middle of the map. Each shopkeeper sells one thing: Corals, the Daily Deal, Decor, or Trades." },
	{ "5. Collect creatures", "Sea creatures visit healthy reefs. Tap one to feed it and add it to your Book." },
	{ "6. Explore", "Use Travel to swim to the Kelp Forest, Shipwreck, and Deep Sea. Each has its own market and rare finds." },
	{ "7. Daily Goals", "Open Goals for daily tasks and your login streak. Come back every day for bigger rewards." },
	{ "8. Rebirth", "When your reef is big, do a Tide Reset from the Shop for a permanent pearl bonus." },
}

local MORE = {
	{ "Pearls", "The main money. Earned by harvesting; spent on corals and slots." },
	{ "Shells", "The rare money. Spent on special corals and decor." },
	{ "Reef level", "The star at the top. Harvesting gives XP; new levels unlock rewards. Tap it to see the next one." },
	{ "Controls", "Tap or click things to use them. Drag to turn the camera, pinch or scroll to zoom." },
	{ "Sound", "The speaker button in the bottom-left turns sound on and off." },
	{ "Graphics", "The Graphics button in the bottom-left switches between High and Low." },
	{ "Photo mode", "Tap Photo in the menu to hide the buttons and take pretty pictures of your reef." },
}

local Help = {}

-- A card that grows to fit its text.
-- Its title is a button, so a card can be tapped (questions open and close).
local function textCard(parent: Instance, order: number, title: string, body: string?): (TextButton, TextLabel?)
	local card = UIKit.card(parent, 0, order)
	card.AutomaticSize = Enum.AutomaticSize.Y
	make("UIPadding", { PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8), PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12), Parent = card })
	make("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder, Parent = card })
	local titleButton = make("TextButton", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Font = UIKit.FONTS.title,
		TextColor3 = COLORS.text,
		TextSize = 17,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = title,
		LayoutOrder = 1,
		Parent = card,
	})
	local bodyLabel = if body
		then UIKit.label(body, { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextSize = 15, Font = UIKit.FONTS.body, LayoutOrder = 2, Parent = card })
		else nil
	return titleButton, bodyLabel
end

function Help.start(gui: ScreenGui, remotes: Instance): () -> ()
	local tutorialRemote = remotes:WaitForChild("Tutorial") :: RemoteEvent
	local tab = "Questions"
	local panel
	local function refresh()
		UIKit.clear(panel.body)
		local row = make("Frame", { Size = UDim2.new(1, -8, 0, 38), BackgroundTransparency = 1, LayoutOrder = 0, Parent = panel.body }, {
			make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6) }),
		})
		for _, name in { "Questions", "How to play", "More" } do
			UIKit.button(name, if name == tab then "accent" else "card", { Size = UDim2.new(1 / 3, -4, 1, 0), TextSize = 15, Parent = row }).Activated:Connect(function()
				tab = name
				refresh()
			end)
		end
		if tab == "Questions" then
			-- Tap a question to show or hide its answer.
			for i, item in FAQ do
				local question, answer = textCard(panel.body, i, "+  " .. item[1], item[2])
				local answerLabel = answer :: TextLabel
				answerLabel.Visible = false
				question.Activated:Connect(function()
					answerLabel.Visible = not answerLabel.Visible
					question.Text = (if answerLabel.Visible then "-  " else "+  ") .. item[1]
				end)
			end
		elseif tab == "How to play" then
			local replay = UIKit.button("Replay the tutorial", "gold", { Size = UDim2.new(1, -8, 0, 40), LayoutOrder = 1, Parent = panel.body })
			replay.Activated:Connect(function()
				tutorialRemote:FireServer("replay")
				panel.toggle()
			end)
			for i, item in GUIDES do
				textCard(panel.body, i + 1, item[1], item[2])
			end
		else
			for i, item in MORE do
				textCard(panel.body, i, item[1], item[2])
			end
		end
	end
	panel = UIKit.panel(gui, "Help", refresh)
	return panel.toggle
end

return Help
