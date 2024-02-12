#import "AppCategories.h"

/*
#!/usr/bin/env python3
# download: https://itunes.apple.com/WebObjects/MZStoreServices.woa/ws/genres
import json
ids = {}

def fn(data):
    for k, v in data.items():
    ids[k] = v['name']
    if 'subgenres' in v:
        fn(v['subgenres'])

with open('genres.json', 'r') as fp:
    for cat in json.load(fp).values():
    if 'App Store' in cat['name']:
        fn(cat['subgenres'])

print(',\n'.join(f'@{k}: @"{v}"' for k, v in ids.items()))
print(len(ids))
*/

NSDictionary *getAppCategories() {
    static NSDictionary* categories = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        categories = @{
            // MARK: iOS
            @6018: @"Books",
            @6000: @"Business",
            @6022: @"Catalogs",
            @6026: @"Developer Tools",
            @6017: @"Education",
            @6016: @"Entertainment",
            @6015: @"Finance",
            @6023: @"Food & Drink",
            @6014: @"Games",
            @7001: @"Action",
            @7002: @"Adventure",
            @7004: @"Board",
            @7005: @"Card",
            @7006: @"Casino",
            @7003: @"Casual",
            @7007: @"Dice",
            @7008: @"Educational",
            @7009: @"Family",
            @7011: @"Music",
            @7012: @"Puzzle",
            @7013: @"Racing",
            @7014: @"Role Playing",
            @7015: @"Simulation",
            @7016: @"Sports",
            @7017: @"Strategy",
            @7018: @"Trivia",
            @7019: @"Word",
            @6027: @"Graphics & Design",
            @6013: @"Health & Fitness",
            @6012: @"Lifestyle",
            @6021: @"Magazines & Newspapers",
            @13007: @"Arts & Photography",
            @13006: @"Automotive",
            @13008: @"Brides & Weddings",
            @13009: @"Business & Investing",
            @13010: @"Children's Magazines",
            @13011: @"Computers & Internet",
            @13012: @"Cooking, Food & Drink",
            @13013: @"Crafts & Hobbies",
            @13014: @"Electronics & Audio",
            @13015: @"Entertainment",
            @13002: @"Fashion & Style",
            @13017: @"Health, Mind & Body",
            @13018: @"History",
            @13003: @"Home & Garden",
            @13019: @"Literary Magazines & Journals",
            @13020: @"Men's Interest",
            @13021: @"Movies & Music",
            @13001: @"News & Politics",
            @13004: @"Outdoors & Nature",
            @13023: @"Parenting & Family",
            @13024: @"Pets",
            @13025: @"Professional & Trade",
            @13026: @"Regional News",
            @13027: @"Science",
            @13005: @"Sports & Leisure",
            @13028: @"Teens",
            @13029: @"Travel & Regional",
            @13030: @"Women's Interest",
            @6020: @"Medical",
            @6011: @"Music",
            @6010: @"Navigation",
            @6009: @"News",
            @6008: @"Photo & Video",
            @6007: @"Productivity",
            @6006: @"Reference",
            @6024: @"Shopping",
            @6005: @"Social Networking",
            @6004: @"Sports",
            @6025: @"Stickers",
            @16003: @"Animals & Nature",
            @16005: @"Art",
            @16006: @"Celebrations",
            @16007: @"Celebrities",
            @16008: @"Comics & Cartoons",
            @16009: @"Eating & Drinking",
            @16001: @"Emoji & Expressions",
            @16026: @"Fashion",
            @16010: @"Gaming",
            @16025: @"Kids & Family",
            @16014: @"Movies & TV",
            @16015: @"Music",
            @16017: @"People",
            @16019: @"Places & Objects",
            @16021: @"Sports & Activities",
            @6003: @"Travel",
            @6002: @"Utilities",
            @6001: @"Weather",

            // MARK: macOS
            @12001: @"Business",
            @12002: @"Developer Tools",
            @12003: @"Education",
            @12004: @"Entertainment",
            @12005: @"Finance",
            @12006: @"Games",
            @12201: @"Action",
            @12202: @"Adventure",
            @12204: @"Board",
            @12205: @"Card",
            @12206: @"Casino",
            @12203: @"Casual",
            @12207: @"Dice",
            @12208: @"Educational",
            @12209: @"Family",
            @12210: @"Kids",
            @12211: @"Music",
            @12212: @"Puzzle",
            @12213: @"Racing",
            @12214: @"Role Playing",
            @12215: @"Simulation",
            @12216: @"Sports",
            @12217: @"Strategy",
            @12218: @"Trivia",
            @12219: @"Word",
            @12022: @"Graphics & Design",
            @12007: @"Health & Fitness",
            @12008: @"Lifestyle",
            @12010: @"Medical",
            @12011: @"Music",
            @12012: @"News",
            @12013: @"Photography",
            @12014: @"Productivity",
            @12015: @"Reference",
            @12016: @"Social Networking",
            @12017: @"Sports",
            @12018: @"Travel",
            @12019: @"Utilities",
            @12020: @"Video",
            @12021: @"Weather"
        };
    });
    return categories;
}
