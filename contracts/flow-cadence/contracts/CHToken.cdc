/*
 * ChargeHive Token (CHT) - Fungible Token for ChargeHive Platform
 *
 * A custom fungible token that implements the Flow FungibleToken standard.
 * Used for rewarding users for charging and parking services on the ChargeHive platform.
 */

import "FungibleToken"
import "FungibleTokenMetadataViews"
import "MetadataViews"
import "ViewResolver"
import "Burner"

access(all) contract CHToken: FungibleToken {

    /// Total supply of CHTokens in circulation
    access(all) var totalSupply: UFix64

    /// Maximum supply cap
    access(all) let maxSupply: UFix64

    /// Storage and Public Paths
    access(all) let VaultStoragePath: StoragePath
    access(all) let VaultPublicPath: PublicPath
    access(all) let ReceiverPublicPath: PublicPath
    access(all) let AdminStoragePath: StoragePath
    access(all) let MinterStoragePath: StoragePath

    /// Events
    access(all) event TokensInitialized(initialSupply: UFix64)
    access(all) event TokensWithdrawn(amount: UFix64, from: Address?)
    access(all) event TokensDeposited(amount: UFix64, to: Address?)
    access(all) event TokensMinted(amount: UFix64, mintedBy: Address?)
    access(all) event TokensBurned(amount: UFix64, burnedFrom: Address?)
    access(all) event MinterCreated(allowedAmount: UFix64)
    access(all) event BurnerCreated()

    /// Vault Resource
    ///
    /// Each user stores an instance of only the Vault in their storage
    /// The functions in the Vault and governed by the FungibleToken standard
    access(all) resource Vault: FungibleToken.Vault {

        /// The total balance of this vault
        access(all) var balance: UFix64

        /// Initialize the balance at resource creation time
        init(balance: UFix64) {
            self.balance = balance
        }

        /// withdraw
        ///
        /// Function that takes an amount as an argument
        /// and withdraws that amount from the Vault.
        ///
        /// It creates a new temporary Vault that is used to hold
        /// the money that is being transferred. It returns the newly
        /// created Vault to the context that called so it can be deposited
        /// elsewhere.
        ///
        access(FungibleToken.Withdraw) fun withdraw(amount: UFix64): @CHToken.Vault {
            self.balance = self.balance - amount
            emit TokensWithdrawn(amount: amount, from: self.owner?.address)
            return <-create Vault(balance: amount)
        }

        /// deposit
        ///
        /// Function that takes a Vault object as an argument and adds
        /// its balance to the balance of the owners Vault.
        ///
        /// It is allowed to destroy the sent Vault because the Vault
        /// was a temporary holder of the tokens. The Vault's balance has
        /// been consumed and therefore can be destroyed.
        ///
        access(all) fun deposit(from: @{FungibleToken.Vault}) {
            let vault <- from as! @CHToken.Vault
            self.balance = self.balance + vault.balance
            emit TokensDeposited(amount: vault.balance, to: self.owner?.address)
            destroy vault
        }

        /// Called when a fungible token is burned via Burner.burn()
        access(contract) fun burnCallback() {
            if self.balance > 0.0 {
                CHToken.totalSupply = CHToken.totalSupply - self.balance
                emit TokensBurned(amount: self.balance, burnedFrom: self.owner?.address)
            }
            self.balance = 0.0
        }

        /// getSupportedVaultTypes
        ///
        /// Returns the types of Vaults that this Vault can accept
        access(all) view fun getSupportedVaultTypes(): {Type: Bool} {
            let supportedTypes: {Type: Bool} = {}
            supportedTypes[self.getType()] = true
            return supportedTypes
        }

        access(all) view fun isSupportedVaultType(type: Type): Bool {
            return self.getSupportedVaultTypes()[type] ?? false
        }

        /// createEmptyVault
        ///
        /// Function that creates a new Vault with a balance of zero
        /// and returns it to the calling context. A user must call this function
        /// and store the returned Vault in their storage in order to allow their
        /// account to be able to receive deposits of this token type.
        ///
        access(all) fun createEmptyVault(): @CHToken.Vault {
            return <-create Vault(balance: 0.0)
        }

        access(all) view fun isAvailableToWithdraw(amount: UFix64): Bool {
            return amount <= self.balance
        }

        /// Get all the Metadata Views implemented by CHToken
        ///
        access(all) view fun getViews(): [Type] {
            return [Type<FungibleTokenMetadataViews.FTView>(),
                    Type<FungibleTokenMetadataViews.FTDisplay>(),
                    Type<FungibleTokenMetadataViews.FTVaultData>(),
                    Type<FungibleTokenMetadataViews.TotalSupply>()]
        }

        /// Resolve a metadata view for this token
        ///
        access(all) fun resolveView(_ view: Type): AnyStruct? {
            return CHToken.resolveContractView(resourceType: nil, viewType: view)
        }
    }

    /// createEmptyVault
    ///
    /// Function that creates a new Vault with a balance of zero
    /// and returns it to the calling context.
    ///
    access(all) fun createEmptyVault(vaultType: Type): @CHToken.Vault {
        return <- create Vault(balance: 0.0)
    }

    /// Minter
    ///
    /// Resource object that token admin accounts can hold to mint new tokens.
    ///
    access(all) resource Minter {

        /// The amount of tokens that the minter is allowed to mint
        access(all) var allowedAmount: UFix64

        /// mintTokens
        ///
        /// Function that mints new tokens, adds them to the total supply,
        /// and returns them to the calling context.
        ///
        access(all) fun mintTokens(amount: UFix64): @CHToken.Vault {
            pre {
                amount > 0.0: "Amount minted must be greater than zero"
                CHToken.totalSupply + amount <= CHToken.maxSupply: "Exceeds maximum supply"
                amount <= self.allowedAmount: "Amount exceeds allowed amount for this minter"
            }
            CHToken.totalSupply = CHToken.totalSupply + amount
            self.allowedAmount = self.allowedAmount - amount
            emit TokensMinted(amount: amount, mintedBy: self.owner?.address)
            return <-create Vault(balance: amount)
        }

        init(allowedAmount: UFix64) {
            self.allowedAmount = allowedAmount
        }
    }

    /// Administrator
    ///
    /// Resource object that has the capability to create new minters
    /// Only the admin can create new Minter resources
    ///
    access(all) resource Administrator {

        /// createNewMinter
        ///
        /// Function that creates and returns a new minter resource
        ///
        access(all) fun createNewMinter(allowedAmount: UFix64): @Minter {
            emit MinterCreated(allowedAmount: allowedAmount)
            return <-create Minter(allowedAmount: allowedAmount)
        }
    }

    /// Get all the Metadata Views implemented by CHToken
    ///
    access(all) view fun getContractViews(resourceType: Type?): [Type] {
        return [Type<FungibleTokenMetadataViews.FTView>(),
                Type<FungibleTokenMetadataViews.FTDisplay>(),
                Type<FungibleTokenMetadataViews.FTVaultData>(),
                Type<FungibleTokenMetadataViews.TotalSupply>()]
    }

    /// Resolve a metadata view for this token
    ///
    access(all) fun resolveContractView(resourceType: Type?, viewType: Type): AnyStruct? {
        switch viewType {
            case Type<FungibleTokenMetadataViews.FTView>():
                return FungibleTokenMetadataViews.FTView(
                    ftDisplay: self.resolveContractView(resourceType: nil, viewType: Type<FungibleTokenMetadataViews.FTDisplay>()) as! FungibleTokenMetadataViews.FTDisplay?,
                    ftVaultData: self.resolveContractView(resourceType: nil, viewType: Type<FungibleTokenMetadataViews.FTVaultData>()) as! FungibleTokenMetadataViews.FTVaultData?
                )
            case Type<FungibleTokenMetadataViews.FTDisplay>():
                let media = MetadataViews.Media(
                    file: MetadataViews.HTTPFile(
                        url: "https://chargehive.com/token-logo.png"
                    ),
                    mediaType: "image/png"
                )
                let medias = MetadataViews.Medias([media])
                return FungibleTokenMetadataViews.FTDisplay(
                    name: "ChargeHive Token",
                    symbol: "CHT",
                    description: "The native token of the ChargeHive peer-to-peer charging and parking platform. Earn CHT by providing charging or parking services to other users.",
                    externalURL: MetadataViews.ExternalURL("https://chargehive.com"),
                    logos: medias,
                    socials: {
                        "twitter": MetadataViews.ExternalURL("https://twitter.com/chargehive")
                    }
                )
            case Type<FungibleTokenMetadataViews.FTVaultData>():
                return FungibleTokenMetadataViews.FTVaultData(
                    storagePath: self.VaultStoragePath,
                    receiverPath: self.ReceiverPublicPath,
                    metadataPath: self.VaultPublicPath,
                    receiverLinkedType: Type<&CHToken.Vault>(),
                    metadataLinkedType: Type<&CHToken.Vault>(),
                    createEmptyVaultFunction: (fun(): @{FungibleToken.Vault} {
                        return <-CHToken.createEmptyVault(vaultType: Type<@CHToken.Vault>())
                    })
                )
            case Type<FungibleTokenMetadataViews.TotalSupply>():
                return FungibleTokenMetadataViews.TotalSupply(
                    totalSupply: CHToken.totalSupply
                )
        }
        return nil
    }

    init() {
        // Set initial supply
        self.totalSupply = 1000000.0

        // Set maximum supply (1 billion tokens)
        self.maxSupply = 1000000000.0

        // Set the named paths
        self.VaultStoragePath = /storage/CHTokenVault
        self.VaultPublicPath = /public/CHTokenVault
        self.ReceiverPublicPath = /public/CHTokenReceiver
        self.AdminStoragePath = /storage/CHTokenAdmin
        self.MinterStoragePath = /storage/CHTokenMinter

        // Create the Vault with the total supply of tokens and save it in storage
        let vault <- create Vault(balance: self.totalSupply)
        self.account.storage.save(<-vault, to: self.VaultStoragePath)

        // Create a public capability to the stored Vault that exposes
        // the Vault interfaces
        let vaultCap = self.account.capabilities.storage.issue<&CHToken.Vault>(
            self.VaultStoragePath
        )
        self.account.capabilities.publish(vaultCap, at: self.ReceiverPublicPath)
        self.account.capabilities.publish(vaultCap, at: self.VaultPublicPath)

        // Create the Administrator resource and save it to storage
        let admin <- create Administrator()
        self.account.storage.save(<-admin, to: self.AdminStoragePath)

        // Emit event
        emit TokensInitialized(initialSupply: self.totalSupply)
    }
}
